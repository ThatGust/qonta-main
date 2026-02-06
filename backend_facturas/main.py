import io
import json
import sqlite3
import os
import time
import shutil
import uuid
from datetime import datetime
from fastapi import FastAPI, File, UploadFile, HTTPException, Form
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from PIL import Image
import uvicorn
from google import genai
from google.genai import types

# --- TU API KEY ---
GOOGLE_API_KEY = ""

client = genai.Client(api_key=GOOGLE_API_KEY)
app = FastAPI()

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

os.makedirs("static/avatars", exist_ok=True) # Asegura que la carpeta exista
app.mount("/static", StaticFiles(directory="static"), name="static")

# --- CONFIGURACIÓN DE BASE DE DATOS (CON USER_ID) ---
def iniciar_base_datos():
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    
    # Tabla Usuarios
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS usuarios (
            id_usuario INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE NOT NULL,
            password TEXT NOT NULL,
            nombre_completo TEXT,
            plan TEXT DEFAULT 'Basic',
            fecha_registro TEXT DEFAULT CURRENT_TIMESTAMP
        )
    ''')

    # Tabla Compras (Ahora tiene user_id)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS compras_sire (
            id_gasto INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            periodo_tributario TEXT,
            fecha_emision TEXT,
            proveedor_ruc TEXT,
            proveedor_razon_social TEXT,
            tipo_comprobante TEXT,
            serie TEXT,
            numero TEXT,
            cod_destino_credito TEXT,
            base_imponible_1 REAL,
            igv_1 REAL,
            monto_total REAL,
            clasificacion_bien_servicio TEXT,
            ruta_imagen TEXT,
            FOREIGN KEY(user_id) REFERENCES usuarios(id_usuario)
        )
    ''')

    # Tabla Ventas (Ahora tiene user_id)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS ventas_sire (
            id_transaccion INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            periodo_tributario TEXT,
            fecha_emision TEXT,
            tipo_comprobante TEXT,
            serie_comprobante TEXT,
            nro_comprobante TEXT,
            cliente_tipo_doc TEXT,
            cliente_nro_doc TEXT,
            cliente_razon_social TEXT,
            valor_exportacion REAL DEFAULT 0,
            base_imponible_gravada REAL DEFAULT 0,
            dscto_base_imponible REAL DEFAULT 0,
            monto_igv REAL DEFAULT 0,
            dscto_igv REAL DEFAULT 0,
            importe_exonerado REAL DEFAULT 0,
            importe_inafecto REAL DEFAULT 0,
            isc REAL DEFAULT 0,
            base_ivap REAL DEFAULT 0,
            ivap REAL DEFAULT 0,
            icbper REAL DEFAULT 0,
            otros_tributos REAL DEFAULT 0,
            total_cp REAL DEFAULT 0,
            moneda TEXT DEFAULT 'PEN',
            tipo_cambio REAL DEFAULT 1.0,
            estado_sire INTEGER DEFAULT 2,
            FOREIGN KEY(user_id) REFERENCES usuarios(id_usuario)
        )
    ''')

    # Crear usuario default por si acaso
    cursor.execute("SELECT count(*) FROM usuarios")
    if cursor.fetchone()[0] == 0:
        cursor.execute('''
            INSERT INTO usuarios (email, password, nombre_completo, plan) 
            VALUES (?, ?, ?, ?)
        ''', ('oscar@qonta.com', '123456', 'Oscar', 'Basic'))
        
    conn.commit()
    conn.close()

iniciar_base_datos()

def verificar_columna_nickname():
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT nickname FROM usuarios LIMIT 1")
    except sqlite3.OperationalError:
        cursor.execute("ALTER TABLE usuarios ADD COLUMN nickname TEXT")
        conn.commit()
    conn.close()

verificar_columna_nickname() # Ejecutar al inicio

def verificar_columna_foto_perfil():
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT foto_perfil FROM usuarios LIMIT 1")
    except sqlite3.OperationalError:
        print("📸 Agregando columna 'foto_perfil' a la tabla usuarios...")
        cursor.execute("ALTER TABLE usuarios ADD COLUMN foto_perfil TEXT DEFAULT 'default_avatar.png'")
        conn.commit()
    conn.close()

verificar_columna_foto_perfil()

def calcular_periodo(fecha_str):
    try:
        dt = datetime.strptime(fecha_str, "%d/%m/%Y")
        return dt.strftime("%Y%m")
    except:
        return datetime.now().strftime("%Y%m")

def guardar_imagen_disco(uploaded_file: UploadFile):
    extension = uploaded_file.filename.split(".")[-1]
    nombre_archivo = f"{uuid.uuid4()}.{extension}"
    ruta_relativa = f"uploads/{nombre_archivo}"
    with open(ruta_relativa, "wb") as buffer:
        shutil.copyfileobj(uploaded_file.file, buffer)
    uploaded_file.file.seek(0)
    return ruta_relativa

# --- ENDPOINT REGISTRO ---
class RegisterRequest(BaseModel):
    nombre: str
    email: str
    password: str

@app.post("/register/")
async def register(usuario: RegisterRequest):
    try:
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        cursor.execute("INSERT INTO usuarios (nombre_completo, email, password) VALUES (?, ?, ?)", 
                       (usuario.nombre, usuario.email, usuario.password))
        conn.commit()
        user_id = cursor.lastrowid
        conn.close()
        return {"status": "ok", "user_id": user_id, "nombre": usuario.nombre}
    except sqlite3.IntegrityError:
        return JSONResponse(content={"error": "El correo ya está registrado"}, status_code=400)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# --- LOGIN ---
class LoginRequest(BaseModel):
    email: str
    password: str

@app.post("/login/")
async def login(usuario: LoginRequest):
    print(f"🔑 Login: {usuario.email}")
    try:
        conn = sqlite3.connect("contabilidad.db")
        conn.row_factory = sqlite3.Row
        cursor = conn.cursor()
        cursor.execute("SELECT * FROM usuarios WHERE email = ? AND password = ?", (usuario.email, usuario.password))
        user = cursor.fetchone()
        conn.close()
        
        if user:
            return {
                "status": "ok",
                "usuario": {
                    "id": user['id_usuario'],
                    "nombre": user['nombre_completo'],
                    "email": user['email'],
                    "plan": user['plan']
                }
            }
        else:
            return JSONResponse(content={"error": "Credenciales incorrectas"}, status_code=401)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# --- ESCANEAR COMPRA (Con user_id) ---
@app.post("/escanear-compra/")
async def escanear_compra(user_id: int = Form(...), file: UploadFile = File(...)):
    print(f"📷 Compra User {user_id}: {file.filename}")
    try:
        ruta_imagen = guardar_imagen_disco(file)
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        prompt = """Analiza COMPRA. Devuelve JSON: {"fecha_emision": "DD/MM/YYYY", "proveedor_ruc": "...", "proveedor_razon_social": "...", "tipo_comprobante": "01/03", "serie": "...", "numero": "...", "cod_destino_credito": "1/5", "base_imponible_1": 0.0, "igv_1": 0.0, "monto_total": 0.0, "clasificacion_bien_servicio": "..."}"""
        
        response = client.models.generate_content(
            model='gemini-flash-latest', contents=[prompt, image],
            config=types.GenerateContentConfig(response_mime_type='application/json')
        )
        datos = json.loads(response.text.strip())
        
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO compras_sire (
                user_id, periodo_tributario, fecha_emision, proveedor_ruc, proveedor_razon_social,
                tipo_comprobante, serie, numero, cod_destino_credito,
                base_imponible_1, igv_1, monto_total, clasificacion_bien_servicio, ruta_imagen
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_id, periodo, datos.get("fecha_emision"), datos.get("proveedor_ruc"),
            datos.get("proveedor_razon_social"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"), datos.get("cod_destino_credito"),
            datos.get("base_imponible_1", 0.0), datos.get("igv_1", 0.0),
            datos.get("monto_total", 0.0), datos.get("clasificacion_bien_servicio"), ruta_imagen
        ))
        conn.commit()
        conn.close()
        return JSONResponse(content={"mensaje": "Escaneo Exitoso", "ruta": ruta_imagen, "datos": datos})
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/escanear-venta/")
async def escanear_venta(user_id: int = Form(...), file: UploadFile = File(...)):
    print(f"📷 Venta User {user_id}: {file.filename}")
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        prompt = """Analiza VENTA. Devuelve JSON: {"fecha_emision": "DD/MM/YYYY", "tipo_comprobante": "01/03", "serie": "...", "numero": "...", "cliente_tipo_doc": "1/6", "cliente_nro_doc": "...", "cliente_razon_social": "...", "total_cp": 0.0, "moneda": "PEN"}"""
        
        response = client.models.generate_content(
            model='gemini-flash-latest', contents=[prompt, image],
            config=types.GenerateContentConfig(response_mime_type='application/json')
        )
        datos = json.loads(response.text.strip())
        
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        cursor.execute('''
            INSERT INTO ventas_sire (
                user_id, periodo_tributario, fecha_emision, tipo_comprobante, 
                serie_comprobante, nro_comprobante, cliente_tipo_doc, cliente_nro_doc, cliente_razon_social,
                total_cp, moneda
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            user_id, periodo, datos.get("fecha_emision"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"), datos.get("cliente_tipo_doc"), 
            datos.get("cliente_nro_doc"), datos.get("cliente_razon_social"),
            datos.get("total_cp", 0.0), datos.get("moneda", "PEN")
        ))
        conn.commit()
        conn.close()
        return JSONResponse(content={"mensaje": "Venta Escaneada", "datos": datos})
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# --- OBTENER REGISTROS (Filtrado por user_id) ---
@app.get("/obtener-registros/{tipo}")
async def obtener_registros(tipo: str, user_id: int):
    try:
        conn = sqlite3.connect("contabilidad.db")
        conn.row_factory = sqlite3.Row 
        cursor = conn.cursor()
        
        registros = []
        if tipo == "compras":
            cursor.execute("SELECT * FROM compras_sire WHERE user_id = ? ORDER BY id_gasto DESC", (user_id,))
            rows = cursor.fetchall()
            for r in rows:
                registros.append({
                    "id": r["id_gasto"],
                    "titulo": r["proveedor_razon_social"] or "Proveedor Desconocido",
                    "fecha": r["fecha_emision"],
                    "monto": r["monto_total"],
                    "categoria": r["clasificacion_bien_servicio"],
                    "foto": r["ruta_imagen"]
                })
        else: # ventas
            cursor.execute("SELECT * FROM ventas_sire WHERE user_id = ? ORDER BY id_transaccion DESC", (user_id,))
            rows = cursor.fetchall()
            for r in rows:
                registros.append({
                    "id": r["id_transaccion"],
                    "titulo": r["cliente_razon_social"] or "Cliente Varios",
                    "fecha": r["fecha_emision"],
                    "monto": r["total_cp"],
                    "categoria": r["tipo_comprobante"],
                    "foto": None 
                })
        
        conn.close()
        return {"datos": registros}
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# --- GUARDAR CONFIRMADO (Con user_id) ---
@app.post("/guardar-confirmado/")
async def guardar_confirmado(payload: dict):
    try:
        tipo = payload.get("tipo")
        datos = payload.get("datos")
        user_id = payload.get("user_id")
        
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        if tipo == "venta":
            cursor.execute('''
                INSERT INTO ventas_sire (user_id, periodo_tributario, fecha_emision, cliente_nro_doc, cliente_razon_social, total_cp, serie_comprobante) 
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (user_id, periodo, datos['fecha_emision'], datos['cliente_nro_doc'], datos['cliente_razon_social'], datos['monto_total'], datos['serie']))
        else:
            cursor.execute('''
                INSERT INTO compras_sire (user_id, periodo_tributario, fecha_emision, proveedor_ruc, proveedor_razon_social, monto_total, serie) 
                VALUES (?, ?, ?, ?, ?, ?, ?)
            ''', (user_id, periodo, datos['fecha_emision'], datos['proveedor_ruc'], datos['proveedor_razon_social'], datos['monto_total'], datos['serie']))
            
        conn.commit()
        conn.close()
        return {"mensaje": "OK"}
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

class PerfilUpdate(BaseModel):
    user_id: int
    nombre_completo: str
    nickname: str

@app.post("/editar-perfil/")
async def editar_perfil(datos: PerfilUpdate):
    try:
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        cursor.execute('''
            UPDATE usuarios
            SET nombre_completo = ?, nickname = ?
            WHERE id_usuario = ?
        ''', (datos.nombre_completo, datos.nickname, datos.user_id))

        if cursor.rowcount == 0:
            conn.close()
            return JSONResponse(content={"error": "Usuario no encontrado"}, status_code=404)

        conn.commit()
        conn.close()
        return {"status": "ok", "mensaje": "Perfil actualizado correctamente"}
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/subir-avatar/")
async def subir_avatar(user_id: int = Form(...), file: UploadFile = File(...)):
    try:
        timestamp = int(time.time())
        filename = f"avatar_{user_id}_{timestamp}.jpg"
        file_location = f"static/avatars/{filename}"

        with open(file_location, "wb+") as file_object:
            shutil.copyfileobj(file.file, file_object)

        relative_path = f"avatars/{filename}"
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        cursor.execute("UPDATE usuarios SET foto_perfil = ? WHERE id_usuario = ?", (relative_path, user_id))
        conn.commit()
        conn.close()

        print(f"Avatar actualizado para usuario {user_id}: {relative_path}")
        return {"status": "ok", "avatar_path": relative_path}

    except Exception as e:
        print(f"Error subiendo avatar: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    print("🚀 Servidor Qonta Multi-usuario Listo...")
    uvicorn.run(app, host="0.0.0.0", port=8000)