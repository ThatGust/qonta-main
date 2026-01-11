import io
import json
import sqlite3
from datetime import datetime
from fastapi import FastAPI, File, UploadFile, Body
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from PIL import Image
import uvicorn
from google import genai
from google.genai import types

# --- TU API KEY ---
GOOGLE_API_KEY = "TU_API_KEY_AQUI"

client = genai.Client(api_key=GOOGLE_API_KEY)
app = FastAPI()

# --- 1. CONFIGURACIÓN DE BASE DE DATOS (SIRE COMPLETO) ---
def iniciar_base_datos():
    conn = sqlite3.connect("contabilidad.db")
    cursor = conn.cursor()
    
    # TABLA COMPRAS (RCE) - Lo que gastas
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
            monto_no_gravado REAL,
            monto_total REAL,
            clasificacion_bien_servicio TEXT
        )
    ''')

    # TABLA VENTAS (RVIE) - Lo que vendes (Manual o Sistema)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS ventas_sire (
            id_transaccion INTEGER PRIMARY KEY AUTOINCREMENT,
            periodo_tributario TEXT,
            cod_car_sunat TEXT,
            fecha_emision TEXT,
            tipo_comprobante TEXT,
            serie_comprobante TEXT,
            nro_comprobante TEXT,
            cliente_tipo_doc TEXT,
            cliente_nro_doc TEXT,
            cliente_razon_social TEXT,
            monto_valor_op_grabada REAL,
            monto_igv REAL,
            monto_icbper REAL,
            monto_total REAL,
            estado_sire INTEGER,
            moneda TEXT,
            tipo_cambio REAL
        )
    ''')
    conn.commit()
    conn.close()

iniciar_base_datos()

# Función auxiliar: Convierte fecha DD/MM/YYYY a Periodo YYYYMM
def calcular_periodo(fecha_str):
    try:
        dt = datetime.strptime(fecha_str, "%d/%m/%Y")
        return dt.strftime("%Y%m")
    except:
        return datetime.now().strftime("%Y%m")

# ==========================================
# 🛒 ENDPOINT 1: ESCANEAR COMPRAS (GASTOS)
# ==========================================
@app.post("/escanear-compra/")
async def escanear_compra(file: UploadFile = File(...)):
    print(f"📷 Analizando COMPRA: {file.filename}...")
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        # Prompt enfocado en PROVEEDOR
        prompt = """
        Actúa como experto contable SUNAT. Analiza este COMPROBANTE DE COMPRA (Gasto).
        Extrae los datos del PROVEEDOR que emitió el documento.
        
        Devuelve SOLO JSON:
        {
            "fecha_emision": "DD/MM/YYYY",
            "proveedor_ruc": "RUC del emisor (11 digitos)",
            "proveedor_razon_social": "Nombre de la empresa emisora",
            "tipo_comprobante": "01 (Factura), 03 (Boleta), 12 (Ticket)",
            "serie": "La serie (ej: F001)",
            "numero": "El numero (ej: 4521)",
            "cod_destino_credito": "1 (Gasto Operativo) o 5 (Gasto Personal)",
            "base_imponible_1": 0.00,
            "igv_1": 0.00,
            "monto_total": 0.00,
            "clasificacion_bien_servicio": "Ej: Mercaderia, Servicios, Activo Fijo"
        }
        """

        response = client.models.generate_content(
            model='gemini-flash-latest', 
            contents=[prompt, image],
            config=types.GenerateContentConfig(response_mime_type='application/json')
        )
        datos = json.loads(response.text.strip())
        print("✅ Compra detectada:", datos)

        # Guardar en BD (Tabla COMPRAS)
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO compras_sire (
                periodo_tributario, fecha_emision, proveedor_ruc, proveedor_razon_social,
                tipo_comprobante, serie, numero, cod_destino_credito,
                base_imponible_1, igv_1, monto_total, clasificacion_bien_servicio
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, datos.get("fecha_emision"), datos.get("proveedor_ruc"),
            datos.get("proveedor_razon_social"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"), datos.get("cod_destino_credito"),
            datos.get("base_imponible_1", 0.0), datos.get("igv_1", 0.0),
            datos.get("monto_total", 0.0), datos.get("clasificacion_bien_servicio")
        ))
        conn.commit()
        conn.close()

        return JSONResponse(content={"tipo": "compra", "mensaje": "Guardado OK", "datos": datos})

    except Exception as e:
        print(f"❌ Error Compra: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)


# ==========================================
# 💰 ENDPOINT 2: ESCANEAR VENTA (MANUAL)
# ==========================================
@app.post("/escanear-venta/")
async def escanear_venta(file: UploadFile = File(...)):
    print(f"📷 Analizando VENTA MANUAL: {file.filename}...")
    try:
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))
        
        # Prompt enfocado en CLIENTE
        prompt = """
        Analiza esta BOLETA DE VENTA MANUAL emitida por mí.
        Extrae los datos de la transacción y del CLIENTE.
        
        Reglas:
        1. 'cliente_tipo_doc': Si hay DNI pon '1', RUC '6', nada '0'.
        2. 'monto_total': El importe final pagado.
        
        Devuelve SOLO JSON:
        {
            "fecha_emision": "DD/MM/YYYY",
            "tipo_comprobante": "01 o 03",
            "serie": "Serie impresa",
            "numero": "Numero correlativo",
            "cliente_tipo_doc": "1, 6 o 0",
            "cliente_nro_doc": "Numero doc cliente",
            "cliente_razon_social": "Nombre cliente",
            "monto_total": 0.00,
            "moneda": "PEN"
        }
        """

        response = client.models.generate_content(
            model='gemini-flash-latest', 
            contents=[prompt, image],
            config=types.GenerateContentConfig(response_mime_type='application/json')
        )
        datos = json.loads(response.text.strip())
        print("✅ Venta detectada:", datos)

        # Cálculos matemáticos (Desglosar IGV del Total)
        total = float(datos.get("monto_total", 0.0))
        base = round(total / 1.18, 2)
        igv = round(total - base, 2)

        # Guardar en BD (Tabla VENTAS)
        periodo = calcular_periodo(datos.get("fecha_emision", ""))
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO ventas_sire (
                periodo_tributario, fecha_emision, tipo_comprobante, 
                serie_comprobante, nro_comprobante, 
                cliente_tipo_doc, cliente_nro_doc, cliente_razon_social,
                monto_valor_op_grabada, monto_igv, monto_total,
                estado_sire, moneda
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, datos.get("fecha_emision"), datos.get("tipo_comprobante"),
            datos.get("serie"), datos.get("numero"),
            datos.get("cliente_tipo_doc"), datos.get("cliente_nro_doc"), 
            datos.get("cliente_razon_social"),
            base, igv, total,
            2, # Estado 2 = Agregado Manualmente
            datos.get("moneda", "PEN")
        ))
        conn.commit()
        conn.close()

        return JSONResponse(content={"tipo": "venta", "mensaje": "Guardado OK", "datos": datos})

    except Exception as e:
        print(f"❌ Error Venta: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)


# ==========================================
# 💻 ENDPOINT 3: REGISTRAR VENTA (SISTEMA)
# ==========================================
class VentaSistema(BaseModel):
    fecha_emision: str
    tipo_comprobante: str
    serie: str
    numero: str
    cliente_tipo_doc: str
    cliente_nro_doc: str
    cliente_razon: str
    base_imponible: float
    igv: float
    total: float
    moneda: str = "PEN"

@app.post("/registrar-venta-sistema/")
async def registrar_venta_sistema(venta: VentaSistema):
    try:
        print(f"💻 Recibiendo Venta Sistema: {venta.serie}-{venta.numero}")
        periodo = calcular_periodo(venta.fecha_emision)
        
        conn = sqlite3.connect("contabilidad.db")
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO ventas_sire (
                periodo_tributario, fecha_emision, tipo_comprobante, 
                serie_comprobante, nro_comprobante, 
                cliente_tipo_doc, cliente_nro_doc, cliente_razon_social,
                monto_valor_op_grabada, monto_igv, monto_total,
                estado_sire, moneda
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            periodo, venta.fecha_emision, venta.tipo_comprobante,
            venta.serie, venta.numero,
            venta.cliente_tipo_doc, venta.cliente_nro_doc, venta.cliente_razon,
            venta.base_imponible, venta.igv, venta.total,
            2, venta.moneda
        ))
        conn.commit()
        conn.close()
        
        return {"mensaje": "Venta Sistema OK"}
    except Exception as e:
        print(f"❌ Error Sistema: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    print("🚀 BACKEND COMPLETO (Compras + Ventas Manuales + Ventas Sistema) LISTO")
    uvicorn.run(app, host="0.0.0.0", port=8000)