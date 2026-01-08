import 'dart:io';
import 'dart:convert'; // Para entender el JSON que manda Python
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(primarySwatch: Colors.indigo), // Color corporativo
    home: FacturaScreen(),
  ));
}

class FacturaScreen extends StatefulWidget {
  @override
  _FacturaScreenState createState() => _FacturaScreenState();
}

class _FacturaScreenState extends State<FacturaScreen> {
  File? _image;
  final picker = ImagePicker();
  bool _isLoading = false; // Para mostrar el círculo de carga
  Map<String, dynamic>? _datosFactura; // Aquí guardaremos lo que responda la IA

  // 1. FUNCION PARA TOMAR FOTO
  Future getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        _datosFactura = null; // Limpiamos datos anteriores
      }
    });
  }

  // 2. FUNCION PARA ENVIAR AL SERVIDOR
  Future uploadImage() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true; // Empieza a girar el círculo
    });

    // --- OJO AQUI: CONFIGURACIÓN DE IP ---
    // Si usas EMULADOR usa: "http://10.0.2.2:8000/escanear/"
    // Si usas CELULAR REAL usa la IP de tu PC: "http://192.168.1.XX:8000/escanear/"
    String urlServidor = "http://192.168.31.102:8000/escanear/"; 

    try {
      var request = http.MultipartRequest('POST', Uri.parse(urlServidor));
      request.files.add(await http.MultipartFile.fromPath('file', _image!.path));

      var response = await request.send();

      if (response.statusCode == 200) {
        // Leemos la respuesta del servidor
        final respStr = await response.stream.bytesToString();
        final jsonResponse = json.decode(respStr);

        setState(() {
          // Guardamos los datos que llegaron dentro de "datos"
          _datosFactura = jsonResponse['datos'];
        });
      } else {
        print("Error en el servidor: ${response.statusCode}");
      }
    } catch (e) {
      print("Error de conexión: $e");
    } finally {
      setState(() {
        _isLoading = false; // Termina de cargar
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Escaner Contable SUNAT')),
      body: SingleChildScrollView( // Permite hacer scroll si la factura es larga
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              // --- AREA DE LA IMAGEN ---
              Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _image == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          Text("Toca el botón para escanear"),
                        ],
                      )
                    : Image.file(_image!, fit: BoxFit.contain),
              ),
              
              SizedBox(height: 20),

              // --- BOTONES ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: getImage,
                    icon: Icon(Icons.camera),
                    label: Text("Capturar"),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : uploadImage, // Se desactiva si carga
                    icon: Icon(Icons.cloud_upload),
                    label: Text("Procesar con IA"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  ),
                ],
              ),

              SizedBox(height: 30),

              // --- RESULTADOS O CARGANDO ---
              if (_isLoading)
                Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("La IA está leyendo la factura..."),
                  ],
                ),

              if (_datosFactura != null)
                Card(
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Datos Extraídos (SUNAT):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Divider(),
                        _filaDato("RUC:", _datosFactura!['ruc_emisor'] ?? "No encontrado"),
                        _filaDato("Fecha:", _datosFactura!['fecha_emision'] ?? "No encontrado"),
                        _filaDato("Total:", "S/ ${_datosFactura!['total']}"),
                        _filaDato("IGV:", "S/ ${_datosFactura!['igv']}"),
                      ],
                    ),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para mostrar los datos ordenados
  Widget _filaDato(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: TextStyle(fontWeight: FontWeight.bold)),
          Text(valor, style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}