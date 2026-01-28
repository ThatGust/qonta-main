import io
import json
import sqlite3
import os
import shutil
import uuid
from datetime import datetime
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from PIL import Image
import uvicorn
from google import genai
from google.genai import types

GOOGLE_API_KEY = ""

client = genai.Client(api_key=GOOGLE_API_KEY)
app = FastAPI()

os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

def iniciar_base_datos():
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    
    # Tabla Compras (Gastos)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS compras_sire (
            id_gasto INTEGER PRIMARY KEY AUTOINCREMENT,
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
            ruta_imagen TEXT
        )
    ''')

    # Tabla Ventas (Estructura SIRE)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS ventas_sire (
            id_transaccion INTEGER PRIMARY KEY AUTOINCREMENT,
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
            estado_sire INTEGER DEFAULT 2
        )
    ''')

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

    cursor.execute("SELECT count(*) FROM usuarios")
    if cursor.fetchone()[0] == 0:
        cursor.execute('''
            INSERT INTO usuarios (email, password, nombre_completo, plan) 
            VALUES (?, ?, ?, ?)
        ''', ('oscar@qonta.com', '123456', 'Oscar', 'Basic'))
        print("👤 Usuario default creado: oscar@qonta.com / 123456")
        
    conn.commit()
    conn.close()

iniciar_base_datos()

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

# ENDPOINT 1: ESCANEAR COMPRA
@app.post("/escanear-compra/")
async def escanear_compra(file: UploadFile = File(...)):
    print(f"📷 Procesando COMPRA: {file.filename}...")
    try:
        ruta_imagen = guardar_imagen_disco(file)
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        prompt = """
        Analiza este COMPROBANTE DE COMPRA (Gasto).
        Extrae datos para SIRE Compras.
        Devuelve SOLO JSON:
        {
            "fecha_emision": "DD/MM/YYYY",
            "proveedor_ruc": "RUC emisor",
            "proveedor_razon_social": "Nombre empresa",
            "tipo_comprobante": "01, 03, etc",
            "serie": "Serie",
            "numero": "Numero",
            "cod_destino_credito": "1 o 5",
            "base_imponible_1": 0.00,
            "igv_1": 0.00,
            "monto_total": 0.00,
            "clasificacion_bien_servicio": "Ej: Mercaderia"
        }
        """
        response = client.models.generate_content(
            model='gemini-flash-latest', 
            contents=[prompt, image],
            config=types.GenerateContentConfig(response_mime_type='application/json')
        )
        datos = json.loads(response.text.strip())
        
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO compras_sire (
                periodo_tributario, fecha_emision, proveedor_ruc, proveedor_razon_social,
                tipo_comprobante, serie, numero, cod_destino_credito,
                base_imponible_1, igv_1, monto_total, 
                clasificacion_bien_servicio, ruta_imagen
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, datos.get("fecha_emision"), datos.get("proveedor_ruc"),
            datos.get("proveedor_razon_social"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"), datos.get("cod_destino_credito"),
            datos.get("base_imponible_1", 0.0), datos.get("igv_1", 0.0),
            datos.get("monto_total", 0.0), datos.get("clasificacion_bien_servicio"),
            ruta_imagen
        ))
        conn.commit()
        conn.close()
        return JSONResponse(content={"mensaje": "Compra Guardada", "ruta": ruta_imagen, "datos": datos})
    except Exception as e:
        print(f"❌ Error Compra: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

# ENDPOINT 2: ESCANEAR VENTA
@app.post("/escanear-venta/")
async def escanear_venta(file: UploadFile = File(...)):
    print(f"📷 Procesando VENTA: {file.filename}...")
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        prompt = """
        Analiza esta BOLETA/FACTURA DE VENTA.
        Extrae TODOS los datos posibles para el Registro de Ventas SIRE detallado.
        Devuelve SOLO JSON con claves exactas:
        {
            "fecha_emision": "DD/MM/YYYY",
            "tipo_comprobante": "01 o 03",
            "serie": "Serie",
            "numero": "Numero",
            "cliente_tipo_doc": "1, 6 o 0",
            "cliente_nro_doc": "Doc cliente",
            "cliente_razon_social": "Nombre cliente",
            "valor_exportacion": 0.00,
            "base_imponible_gravada": 0.00,
            "dscto_base_imponible": 0.00,
            "monto_igv": 0.00,
            "dscto_igv": 0.00,
            "importe_exonerado": 0.00,
            "importe_inafecto": 0.00,
            "isc": 0.00,
            "base_ivap": 0.00,
            "ivap": 0.00,
            "icbper": 0.00,
            "otros_tributos": 0.00,
            "total_cp": 0.00,
            "moneda": "PEN"
        }
        """
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
                periodo_tributario, fecha_emision, tipo_comprobante, 
                serie_comprobante, nro_comprobante, cliente_tipo_doc, cliente_nro_doc, cliente_razon_social,
                valor_exportacion, base_imponible_gravada, dscto_base_imponible,
                monto_igv, dscto_igv, importe_exonerado, importe_inafecto,
                isc, base_ivap, ivap, icbper, otros_tributos, total_cp, moneda
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, datos.get("fecha_emision"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"),
            datos.get("cliente_tipo_doc"), datos.get("cliente_nro_doc"), 
            datos.get("cliente_razon_social"),
            datos.get("valor_exportacion", 0), datos.get("base_imponible_gravada", 0),
            datos.get("dscto_base_imponible", 0), datos.get("monto_igv", 0),
            datos.get("dscto_igv", 0), datos.get("importe_exonerado", 0),
            datos.get("importe_inafecto", 0), datos.get("isc", 0),
            datos.get("base_ivap", 0), datos.get("ivap", 0),
            datos.get("icbper", 0), datos.get("otros_tributos", 0),
            datos.get("total_cp", 0), datos.get("moneda", "PEN")
        ))
        conn.commit()
        conn.close()
        return JSONResponse(content={"mensaje": "Venta Escaneada", "datos": datos})
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# ENDPOINT 3: REGISTRO MANUAL SISTEMA
class VentaSistema(BaseModel):
    fecha_emision: str
    total_cp: float
    # ... otros campos simplificados para este ejemplo

class LoginRequest(BaseModel):
    email: str
    password: str

@app.post("/registrar-venta-sistema/")
async def registrar_venta_sistema(venta: VentaSistema):
    # Simplificado por brevedad, usa la lógica similar a escanear-venta
    return {"mensaje": "Ok"}

# ENDPOINT 4: OBTENER REGISTROS
@app.get("/obtener-registros/{tipo}")
async def obtener_registros(tipo: str):
    print(f"📋 Consultando registros de: {tipo}")
    try:
        conn = sqlite3.connect("contabilidad.db")
        conn.row_factory = sqlite3.Row 
        cursor = conn.cursor()
        
        registros = []
        if tipo == "compras":
            cursor.execute("SELECT * FROM compras_sire ORDER BY id_gasto DESC")
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
            cursor.execute("SELECT * FROM ventas_sire ORDER BY id_transaccion DESC")
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
        print(f"❌ Error al obtener registros: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

# ENDPOINT 5: GUARDAR EDICIÓN CONFIRMADA
@app.post("/guardar-confirmado/")
async def guardar_confirmado(payload: dict):
    print("💾 Guardando edición manual...")
    try:
        tipo = payload.get("tipo")
        datos = payload.get("datos")
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        monto_total = float(datos['monto_total'])
        # Calculamos Base e IGV aproximado para que la BD no tenga ceros
        base = round(monto_total / 1.18, 2)
        igv = round(monto_total - base, 2)
        
        if tipo == "venta":
            # Guardamos en ventas_sire con el desglose básico
            cursor.execute('''
                INSERT INTO ventas_sire (
                    periodo_tributario, fecha_emision, cliente_nro_doc, 
                    cliente_razon_social, serie_comprobante, 
                    total_cp, base_imponible_gravada, monto_igv
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                periodo, datos['fecha_emision'], datos['cliente_nro_doc'], 
                datos['cliente_razon_social'], datos['serie'], 
                monto_total, base, igv
            ))
        else:
            # Guardamos en compras_sire
            cursor.execute('''
                INSERT INTO compras_sire (
                    periodo_tributario, fecha_emision, proveedor_ruc, 
                    proveedor_razon_social, serie,
                    monto_total, base_imponible_1, igv_1
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                periodo, datos['fecha_emision'], datos['proveedor_ruc'], 
                datos['proveedor_razon_social'], datos['serie'], 
                monto_total, base, igv
            ))
            
        conn.commit()
        conn.close()
        return {"mensaje": "OK"}
    except Exception as e:
        print(f"❌ Error al guardar confirmado: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)
    

@app.post("/login/")
async def login(usuario: LoginRequest):
    print(f"🔑 Intentando login para: {usuario.email}")
    try:
        conn = sqlite3.connect("contabilidad.db")
        conn.row_factory = sqlite3.Row # Esto es clave para acceder por nombre de columna
        cursor = conn.cursor()
        
        # Buscamos al usuario por email y contraseña
        # (Nota: En producción real, las contraseñas se encriptan, aquí usamos texto simple para prototipo)
        cursor.execute("SELECT * FROM usuarios WHERE email = ? AND password = ?", (usuario.email, usuario.password))
        user = cursor.fetchone()
        
        conn.close()
        
        if user:
            print(f"✅ Bienvenido {user['nombre_completo']}")
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
            print("❌ Credenciales incorrectas")
            # Devolvemos un error 401 (No autorizado) si falla
            return JSONResponse(content={"error": "Email o contraseña incorrectos"}, status_code=401)
            
    except Exception as e:
        print(f"❌ Error en login: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    print("🚀 Servidor Qonta Listo en 192.168.0.2:8000...")
    uvicorn.run(app, host="192.168.0.2", port=8000)