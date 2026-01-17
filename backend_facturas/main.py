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

# --- TU API KEY ---
GOOGLE_API_KEY = "AIzaSyA4GsKVGCT8DsSNK2LNQEbr1utpD-GRr3w"

client = genai.Client(api_key=GOOGLE_API_KEY)
app = FastAPI()

# 1. Crear carpeta para guardar imagenes si no existe
os.makedirs("uploads", exist_ok=True)

# 2. Servir archivos estáticos
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# --- CONFIGURACIÓN DE BASE DE DATOS (NUEVA ESTRUCTURA SIRE DETALLADA) ---
def iniciar_base_datos():
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    
    # Tabla COMPRAS (Se mantiene igual, para tus gastos)
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

    # Tabla VENTAS (REEMPLAZADA con la estructura del reporte SIRE)
    # Nota: Si ya existe la tabla con estructura vieja, idealmente borra el archivo .db para recrearlo limpio
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS ventas_sire (
            id_transaccion INTEGER PRIMARY KEY AUTOINCREMENT,
            periodo_tributario TEXT,
            fecha_emision TEXT,
            tipo_comprobante TEXT,       -- 01-Factura, 03-Boleta, etc.
            serie_comprobante TEXT,
            nro_comprobante TEXT,
            
            cliente_tipo_doc TEXT,       -- 1 (DNI), 6 (RUC)
            cliente_nro_doc TEXT,
            cliente_razon_social TEXT,
            
            -- COLUMNAS DEL REPORTE SIRE --
            valor_exportacion REAL DEFAULT 0,
            base_imponible_gravada REAL DEFAULT 0,
            dscto_base_imponible REAL DEFAULT 0,
            monto_igv REAL DEFAULT 0,
            dscto_igv REAL DEFAULT 0,
            importe_exonerado REAL DEFAULT 0,
            importe_inafecto REAL DEFAULT 0,
            isc REAL DEFAULT 0,          -- Impuesto Selectivo al Consumo
            base_ivap REAL DEFAULT 0,    -- Arroz Pilado Base
            ivap REAL DEFAULT 0,         -- Arroz Pilado Impuesto
            icbper REAL DEFAULT 0,       -- Impuesto Bolsas Plasticas
            otros_tributos REAL DEFAULT 0,
            
            total_cp REAL DEFAULT 0,     -- Total Comprobante
            
            moneda TEXT DEFAULT 'PEN',
            tipo_cambio REAL DEFAULT 1.0,
            estado_sire INTEGER DEFAULT 2
        )
    ''')
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

# ==========================================
# 🛒 ENDPOINT 1: ESCANEAR COMPRAS (GASTOS)
# ==========================================
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


# ==========================================
# 💰 ENDPOINT 2: ESCANEAR VENTA (ESTRUCTURA SIRE COMPLETA)
# ==========================================
@app.post("/escanear-venta/")
async def escanear_venta(file: UploadFile = File(...)):
    print(f"📷 Procesando VENTA: {file.filename}...")
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        # PROMPT ACTUALIZADO CON LOS NUEVOS CAMPOS
        prompt = """
        Analiza esta BOLETA/FACTURA DE VENTA.
        Extrae TODOS los datos posibles para el Registro de Ventas SIRE detallado.
        
        Reglas:
        1. Busca descuentos, ISC, ICBPER (bolsas), Exonerados, etc.
        2. Si no encuentras un valor, pon 0.00.
        3. 'cliente_tipo_doc': 1=DNI, 6=RUC, 0=Sin Doc.
        
        Devuelve SOLO JSON:
        {
            "fecha_emision": "DD/MM/YYYY",
            "tipo_comprobante": "01 (Factura) o 03 (Boleta)",
            "serie": "Serie",
            "numero": "Numero",
            "cliente_tipo_doc": "1, 6 o 0",
            "cliente_nro_doc": "Numero documento",
            "cliente_razon_social": "Nombre Razon Social",
            
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
        
        # Insertar con TODOS los campos nuevos
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO ventas_sire (
                periodo_tributario, fecha_emision, tipo_comprobante, 
                serie_comprobante, nro_comprobante, 
                cliente_tipo_doc, cliente_nro_doc, cliente_razon_social,
                
                valor_exportacion, base_imponible_gravada, dscto_base_imponible,
                monto_igv, dscto_igv, importe_exonerado, importe_inafecto,
                isc, base_ivap, ivap, icbper, otros_tributos,
                total_cp, moneda
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, datos.get("fecha_emision"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"),
            datos.get("cliente_tipo_doc"), datos.get("cliente_nro_doc"), 
            datos.get("cliente_razon_social"),
            
            datos.get("valor_exportacion", 0),
            datos.get("base_imponible_gravada", 0),
            datos.get("dscto_base_imponible", 0),
            datos.get("monto_igv", 0),
            datos.get("dscto_igv", 0),
            datos.get("importe_exonerado", 0),
            datos.get("importe_inafecto", 0),
            datos.get("isc", 0),
            datos.get("base_ivap", 0),
            datos.get("ivap", 0),
            datos.get("icbper", 0),
            datos.get("otros_tributos", 0),
            datos.get("total_cp", 0),
            datos.get("moneda", "PEN")
        ))
        conn.commit()
        conn.close()

        # Devolvemos el JSON completo para que tu App muestre la plantilla de edición
        return JSONResponse(content={"mensaje": "Venta Escaneada", "datos": datos})

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# ==========================================
# 💻 ENDPOINT 3: REGISTRAR VENTA (SISTEMA - MANUAL)
# ==========================================
# Modelo actualizado para recibir la edición completa desde la App
class VentaSistema(BaseModel):
    fecha_emision: str
    tipo_comprobante: str
    serie: str
    numero: str
    cliente_tipo_doc: str
    cliente_nro_doc: str
    cliente_razon: str
    
    valor_exportacion: float = 0.0
    base_imponible_gravada: float = 0.0
    dscto_base_imponible: float = 0.0
    monto_igv: float = 0.0
    dscto_igv: float = 0.0
    importe_exonerado: float = 0.0
    importe_inafecto: float = 0.0
    isc: float = 0.0
    base_ivap: float = 0.0
    ivap: float = 0.0
    icbper: float = 0.0
    otros_tributos: float = 0.0
    total_cp: float = 0.0
    
    moneda: str = "PEN"

@app.post("/registrar-venta-sistema/")
async def registrar_venta_sistema(venta: VentaSistema):
    try:
        periodo = calcular_periodo(venta.fecha_emision)
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO ventas_sire (
                periodo_tributario, fecha_emision, tipo_comprobante, 
                serie_comprobante, nro_comprobante, 
                cliente_tipo_doc, cliente_nro_doc, cliente_razon_social,
                
                valor_exportacion, base_imponible_gravada, dscto_base_imponible,
                monto_igv, dscto_igv, importe_exonerado, importe_inafecto,
                isc, base_ivap, ivap, icbper, otros_tributos,
                total_cp, moneda
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, venta.fecha_emision, venta.tipo_comprobante,
            venta.serie, venta.numero,
            venta.cliente_tipo_doc, venta.cliente_nro_doc, venta.cliente_razon,
            
            venta.valor_exportacion, venta.base_imponible_gravada, venta.dscto_base_imponible,
            venta.monto_igv, venta.dscto_igv, venta.importe_exonerado, venta.importe_inafecto,
            venta.isc, venta.base_ivap, venta.ivap, venta.icbper, venta.otros_tributos,
            venta.total_cp, venta.moneda
        ))
        conn.commit()
        conn.close()
        return {"mensaje": "Venta Sistema OK"}
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)
    
# --- AÑADE ESTOS ENDPOINTS AL FINAL DE TU main.py ---

@app.get("/obtener-registros/{tipo}")
async def obtener_registros(tipo: str):
    print(f"📋 Consultando registros de: {tipo}")
    try:
        conn = sqlite3.connect("contabilidad.db")
        conn.row_factory = sqlite3.Row # Permite acceder por nombre de columna
        cursor = conn.cursor()
        
        registros = []
        if tipo == "compras":
            cursor.execute("SELECT * FROM compras_sire ORDER BY id_gasto DESC")
            rows = cursor.fetchall()
            for r in rows:
                registros.append({
                    "id": r["id_gasto"],
                    "titulo": r["proveedor_razon_social"],
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
                    "titulo": r["cliente_razon_social"],
                    "fecha": r["fecha_emision"],
                    "monto": r["total_cp"],
                    "categoria": r["tipo_comprobante"],
                    "foto": None # Las ventas no suelen llevar foto en tu estructura
                })
        
        conn.close()
        return {"datos": registros}
    except Exception as e:
        print(f"❌ Error al obtener registros: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

# Endpoint para guardar lo confirmado desde la pantalla amarilla de Flutter
@app.post("/guardar-confirmado/")
async def guardar_confirmado(payload: dict):
    try:
        tipo = payload.get("tipo")
        datos = payload.get("datos")
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        if tipo == "venta":
            cursor.execute('''
                INSERT INTO ventas_sire (
                    periodo_tributario, fecha_emision, cliente_nro_doc, 
                    cliente_razon_social, total_cp, serie_comprobante
                ) VALUES (?, ?, ?, ?, ?, ?)
            ''', (periodo, datos['fecha_emision'], datos['cliente_nro_doc'], 
                  datos['cliente_razon_social'], datos['monto_total'], datos['serie']))
        else:
            cursor.execute('''
                INSERT INTO compras_sire (
                    periodo_tributario, fecha_emision, proveedor_ruc, 
                    proveedor_razon_social, monto_total, serie
                ) VALUES (?, ?, ?, ?, ?, ?)
            ''', (periodo, datos['fecha_emision'], datos['proveedor_ruc'], 
                  datos['proveedor_razon_social'], datos['monto_total'], datos['serie']))
            
        conn.commit()
        conn.close()
        return {"mensaje": "OK"}
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    print("🚀 Servidor SIRE Completo Actualizado...")
    # Asegurate de que la IP sea la de tu máquina
    uvicorn.run(app, host="192.168.0.2", port=8000)