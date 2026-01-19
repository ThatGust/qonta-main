# Escáner Contable con IA (SUNAT Perú)

Este proyecto es una aplicación móvil que permite escanear facturas y boletas físicas peruanas usando la cámara del celular. Utiliza Inteligencia Artificial (**Google Gemini**) para extraer automáticamente datos clave (RUC, Fecha, Total, IGV) y los guarda en un Libro Contable digital (Excel/CSV).

##  Tecnologías

* **Frontend:** Flutter (Dart) - Aplicación Móvil Android.
* **Backend:** Python (FastAPI + Uvicorn).
* **IA:** Google Gemini (Librería `google-genai`).
* **Datos:** Pandas (CSV/Excel).

---

##  Requisitos Previos

Asegúrate de tener instalado en tu PC:
1.  **Git** (Para descargar el código).
2.  **Python 3.10+** (Para el servidor).
3.  **Flutter SDK** (Para la app móvil).
4.  **VS Code** (Editor recomendado).

---

##  Instalación y Configuración

Sigue estos pasos en orden para poner todo a funcionar en una nueva PC.

### 1. Clonar el repositorio
Abre una terminal y ejecuta:
```bash
git clone [https://github.com/TU_USUARIO/NOMBRE_DEL_REPO.git](https://github.com/TU_USUARIO/NOMBRE_DEL_REPO.git)
cd Sistema_Facturas_IA

```

### 2. Configurar el Backend (Servidor)
Entra a la carpeta del backend:

```Bash

cd backend_facturas

```

Instala las librerías necesarias:

```Bash

py -m pip install fastapi uvicorn google-genai pandas pillow python-multipart
```
#CONFIGURAR API KEY:

#Abre el archivo main.py.

#Busca la variable GOOGLE_API_KEY.

#Borra el texto de ejemplo y pega tu propia clave de Google AI Studio.

#Nota: ¡No subas tu clave real al repositorio de GitHub!

#Enciende el servidor:

```Bash

py main.py
```
Debe decir:  Servidor con Gemini Flash Latest listo...

3. Configurar el Frontend (App Móvil)
Abre una nueva terminal (sin cerrar la del servidor) y entra a la carpeta de la app:

```Bash

cd app_facturas
Descarga las dependencias de Flutter:
Bash

flutter pub get
```
CONFIGURACIÓN DE IP (¡Paso Vital!): Para que el celular se comunique con tu PC, necesitas la IP local.

#En tu PC, abre terminal y escribe ipconfig. Copia la IPv4 (ej: 192.168.1.15).

#En VS Code, abre lib/main.dart.

#Busca la línea: var url = Uri.parse(...).

#Reemplaza la IP por la tuya. Ejemplo:
```
Dart

var url = Uri.parse("[http://192.168.1.15:8000/escanear/](http://192.168.1.15:8000/escanear/)");
Ejecuta la app (con celular conectado o emulador):

Bash

flutter run
```
 Cómo usar
#Verifica que el Servidor Python esté corriendo (terminal abierta).

#En la App, presiona "Cámara" y toma la foto del recibo.

#Presiona "Analizar".

#Espera unos segundos y verás el RUC, Fecha y Montos en pantalla.

#Los datos se guardan automáticamente en backend_facturas/libro_contable.csv.
