import io
import json
import pandas as pd
from fastapi import FastAPI, File, UploadFile
from fastapi.responses import JSONResponse
from PIL import Image
import uvicorn
from google import genai 
from google.genai import types

# --- TU API KEY ---
GOOGLE_API_KEY = "PON_AQUI_TU_API_KEY"

# Cliente de la nueva libreria
client = genai.Client(api_key=GOOGLE_API_KEY)

app = FastAPI()

@app.post("/escanear/")
async def procesar_factura(file: UploadFile = File(...)):
    print(f"📷 Recibiendo imagen: {file.filename}...")
    
    try:
        # 1. Cargar imagen en Memoria (RAM)
        contents = await file.read()
        image = Image.open(io.BytesIO(contents))

        # 2. Prompt para la IA
        prompt = """
        Analiza este documento tributario peruano (Factura o Boleta de Venta).
        Extrae y devuelve SOLO este JSON con estas claves exactas:
        {
            "ruc_emisor": "El RUC del emisor (ej: 20510556594)",
            "fecha_emision": "La fecha de emision (DD/MM/YYYY)",
            "total": "El monto total (numero decimal)",
            "igv": "El monto del IGV (numero decimal)"
        }
        """

        # 3. Enviar a Gemini (Usando el nombre de TU captura)
        # Usamos 'gemini-flash-latest' que es el que te aparece disponible
        response = client.models.generate_content(
            model='gemini-flash-latest', 
            contents=[prompt, image],
            config=types.GenerateContentConfig(
                response_mime_type='application/json' 
            )
        )
        
        # 4. Limpiar y leer respuesta
        # A veces la IA devuelve texto extra, aseguramos que sea JSON
        texto_limpio = response.text.strip()
        if texto_limpio.startswith("```json"):
            texto_limpio = texto_limpio.replace("```json", "").replace("```", "")
            
        datos = json.loads(texto_limpio)
        print("✅ Datos extraídos:", datos)

        # 5. Guardar en CSV
        try:
            df = pd.DataFrame([datos])
            existe = False
            try:
                with open("libro_contable.csv", "r") as f: existe = True
            except: existe = False
            df.to_csv("libro_contable.csv", mode='a', header=not existe, index=False)
        except Exception as e:
            print(f"⚠️ Error CSV (no crítico): {e}")

        return JSONResponse(content={"mensaje": "Exito", "datos": datos})

    except Exception as e:
        print(f"❌ Error: {e}")
        return JSONResponse(content={"error": str(e)}, status_code=500)

if __name__ == "__main__":
    print("🚀 Servidor con Gemini Flash Latest listo...")
    uvicorn.run(app, host="0.0.0.0", port=8000)