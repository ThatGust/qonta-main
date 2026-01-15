import io
import json
import sqlite3
import os
import shutil
import uuid
from datetime import datetime
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles # <--- NUEVO
from pydantic import BaseModel
from PIL import Image
import uvicorn
from google import genai
from google.genai import types

# --- TU API KEY ---
GOOGLE_API_KEY = "AIzaSyD03rkw8XJu32cAGmcVhGxgEaOPEKQLm7I"

client = genai.Client(api_key=GOOGLE_API_KEY)
app = FastAPI()

# 1. CREAR CARPETA PARA IMAGENES
os.makedirs("uploads", exist_ok=True)
# Esto permite que la app vea las fotos entrando a http://ip:8000/uploads/foto.jpg
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# --- CONFIGURACIÓN BD ---
def iniciar_base_datos():
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    # Agregamos columna 'ruta_imagen' si no existe
    try:
        cursor.execute("ALTER TABLE compras_sire ADD COLUMN ruta_imagen TEXT")
    except: pass
    
    # Tablas (Simplificadas para el ejemplo, asegúrate de tener las tuyas completas)
    cursor.execute('''CREATE TABLE IF NOT EXISTS compras_sire (
        id_gasto INTEGER PRIMARY KEY AUTOINCREMENT,
        periodo_tributario TEXT, fecha_emision TEXT, proveedor_ruc TEXT, 
        proveedor_razon_social TEXT, tipo_comprobante TEXT, serie TEXT, numero TEXT,
        monto_total REAL, clasificacion_bien_servicio TEXT, ruta_imagen TEXT
    )''')
    cursor.execute('''CREATE TABLE IF NOT EXISTS ventas_sire (
        id_transaccion INTEGER PRIMARY KEY AUTOINCREMENT,
        periodo_tributario TEXT, fecha_emision TEXT, cliente_razon_social TEXT,
        tipo_comprobante TEXT, serie_comprobante TEXT, nro_comprobante TEXT,
        monto_total REAL, ruta_imagen TEXT
    )''')
    conn.commit()
    conn.close()

iniciar_base_datos()

def calcular_periodo(fecha_str):
    try:
        dt = datetime.strptime(fecha_str, "%d/%m/%Y")
        return dt.strftime("%Y%m")
    except: return datetime.now().strftime("%Y%m")

# --- NUEVO: OBTENER LISTA DE REGISTROS (Para la pantalla "Mis Registros") ---
@app.get("/obtener-registros/{tipo}")
async def obtener_registros(tipo: str):
    """
    tipo: 'compras' o 'ventas'
    Devuelve la lista ordenada por fecha.
    """
    conn = sqlite3.connect("contabilidad.db")
    conn.row_factory = sqlite3.Row # Para obtener diccionarios
    cursor = conn.cursor()
    
    registros = []
    if tipo == "compras":
        cursor.execute("SELECT * FROM compras_sire ORDER BY id_gasto DESC")
        rows = cursor.fetchall()
        for r in rows:
            registros.append({
                "id": r["id_gasto"],
                "fecha": r["fecha_emision"],
                "titulo": r["proveedor_razon_social"] or "Proveedor Desconocido",
                "monto": r["monto_total"],
                "categoria": r["clasificacion_bien_servicio"] or "Gasto General",
                "foto": r["ruta_imagen"]
            })
    else:
        cursor.execute("SELECT * FROM ventas_sire ORDER BY id_transaccion DESC")
        rows = cursor.fetchall()
        for r in rows:
            registros.append({
                "id": r["id_transaccion"],
                "fecha": r["fecha_emision"],
                "titulo": r["cliente_razon_social"] or "Cliente Varios",
                "monto": r["monto_total"],
                "categoria": "Ingreso / Venta",
                "foto": r["ruta_imagen"] if "ruta_imagen" in r.keys() else None
            })
            
    conn.close()
    return JSONResponse(content={"datos": registros})

# --- NUEVO: EDITAR REGISTRO ---
class EdicionModel(BaseModel):
    id: int
    tipo: str # 'compras' o 'ventas'
    nuevo_monto: float
    nueva_fecha: str

@app.put("/editar-registro/")
async def editar_registro(datos: EdicionModel):
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    
    try:
        if datos.tipo == "compras":
            cursor.execute("UPDATE compras_sire SET monto_total=?, fecha_emision=? WHERE id_gasto=?", 
                           (datos.nuevo_monto, datos.nueva_fecha, datos.id))
        else:
            cursor.execute("UPDATE ventas_sire SET monto_total=?, fecha_emision=? WHERE id_transaccion=?", 
                           (datos.nuevo_monto, datos.nueva_fecha, datos.id))
        conn.commit()
        return {"mensaje": "Registro actualizado correctamente"}
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)
    finally:
        conn.close()

# --- MODIFICADO: ESCANEAR COMPRA (AHORA GUARDA LA FOTO) ---
@app.post("/escanear-compra/")
async def escanear_compra(file: UploadFile = File(...)):
    print(f"📷 Procesando GASTO: {file.filename}")
    
    # 1. Guardar imagen en disco
    nombre_archivo = f"{uuid.uuid4()}.jpg"
    ruta_guardado = f"uploads/{nombre_archivo}"
    
    with open(ruta_guardado, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # 2. Procesar con Gemini (leemos el archivo guardado)
    image = Image.open(ruta_guardado)
    
    # ... (Tu prompt de Gemini sigue igual) ...
    prompt = """Actúa como experto contable. Extrae JSON: 
    { "fecha_emision": "DD/MM/YYYY", "proveedor_ruc": "...", "proveedor_razon_social": "...", 
      "tipo_comprobante": "01/03", "serie": "...", "numero": "...", "monto_total": 0.00, 
      "clasificacion_bien_servicio": "..." }"""
    
    try:
        response = client.models.generate_content(
            model='gemini-flash-latest', contents=[prompt, image],
            config=types.GenerateContentConfig(response_mime_type='application/json')
        )
        datos = json.loads(response.text.strip())
        
        # 3. Guardar en BD con la RUTA DE LA FOTO
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        
        cursor.execute('''
            INSERT INTO compras_sire (
                periodo_tributario, fecha_emision, proveedor_ruc, proveedor_razon_social,
                tipo_comprobante, serie, numero, monto_total, clasificacion_bien_servicio, ruta_imagen
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, datos.get("fecha_emision"), datos.get("proveedor_ruc"),
            datos.get("proveedor_razon_social"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"), datos.get("monto_total", 0.0),
            datos.get("clasificacion_bien_servicio"), 
            ruta_guardado # <--- GUARDAMOS LA RUTA
        ))
        conn.commit()
        conn.close()
        
        return JSONResponse(content={"datos": datos})
    except Exception as e:
        print(e)
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    uvicorn.run(app, host="192.168.31.102", port=8000)