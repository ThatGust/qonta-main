import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema Contable IA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- CONFIGURACIÓN ---
  // ⚠️ IMPORTANTE: Cambia esto por la IP de tu computadora (ipconfig)
  final String ipAddress = "192.168.31.102"; 
  
  File? _image;
  bool _isLoading = false;
  Map<String, dynamic>? _resultado;
  String _tipoOperacion = ""; // 'compra' o 'venta'

  final ImagePicker _picker = ImagePicker();

  // Función principal: Toma la foto y la envía al endpoint correcto
  Future<void> _procesarImagen({required bool esVenta}) async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);

    if (photo == null) return;

    setState(() {
      _image = File(photo.path);
      _isLoading = true;
      _resultado = null;
      _tipoOperacion = esVenta ? "venta" : "compra";
    });

    // Definimos a qué endpoint ir
    String endpoint = esVenta ? "escanear-venta" : "escanear-compra";
    var uri = Uri.parse("http://$ipAddress:8000/$endpoint/");

    try {
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', _image!.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          _resultado = data['datos']; // Accedemos al objeto 'datos' del JSON
          _isLoading = false;
        });
      } else {
        _mostrarError("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      _mostrarError("Error de conexión: $e");
    }
  }

  void _mostrarError(String mensaje) {
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Escáner Contable SIRE"),
        centerTitle: true,
        backgroundColor: Colors.blue[800],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Selecciona el tipo de operación:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // --- BOTONES DE ACCIÓN ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _procesarImagen(esVenta: false),
                    icon: const Icon(Icons.shopping_cart, size: 30),
                    label: const Text("REGISTRAR\nCOMPRA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[100],
                      foregroundColor: Colors.orange[900],
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _procesarImagen(esVenta: true),
                    icon: const Icon(Icons.attach_money, size: 30),
                    label: const Text("REGISTRAR\nVENTA"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[100],
                      foregroundColor: Colors.green[900],
                      padding: const EdgeInsets.symmetric(vertical: 20),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // --- VISTA PREVIA DE IMAGEN ---
            if (_image != null)
              Container(
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(_image!, fit: BoxFit.cover),
                ),
              ),

            const SizedBox(height: 20),

            // --- INDICADOR DE CARGA ---
            if (_isLoading)
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Gemini analizando documento..."),
                  ],
                ),
              ),

            // --- RESULTADOS ---
            if (_resultado != null) _buildResultCard(),
          ],
        ),
      ),
    );
  }

  // Widget para mostrar los datos dependiendo si es Compra o Venta
  Widget _buildResultCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _tipoOperacion == 'venta' ? "VENTA MANUAL" : "GASTO / COMPRA",
                  style: TextStyle(
                    color: _tipoOperacion == 'venta' ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const Divider(),
            
            // Campos comunes
            _infoRow("Fecha:", _resultado?['fecha_emision']),
            _infoRow("Tipo:", _resultado?['tipo_comprobante'] == '01' ? 'Factura' : 'Boleta'),
            _infoRow("Doc:", "${_resultado?['serie']} - ${_resultado?['numero']}"),

            const Divider(),
            
            // Campos Específicos
            if (_tipoOperacion == 'compra') ...[
              const Text("DATOS PROVEEDOR:", style: TextStyle(fontWeight: FontWeight.bold)),
              _infoRow("RUC:", _resultado?['proveedor_ruc']),
              _infoRow("Razón Social:", _resultado?['proveedor_razon_social']),
              _infoRow("Clasificación:", _resultado?['clasificacion_bien_servicio']),
            ] else ...[
              const Text("DATOS CLIENTE:", style: TextStyle(fontWeight: FontWeight.bold)),
              _infoRow("Tipo Doc:", _resultado?['cliente_tipo_doc'] == '1' ? 'DNI' : 'RUC'),
              _infoRow("Número:", _resultado?['cliente_nro_doc']),
              _infoRow("Nombre:", _resultado?['cliente_razon_social']),
            ],

            const Divider(),
            
            // Totales
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("TOTAL:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    "S/ ${_resultado?['monto_total']}",
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100, 
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value?.toString() ?? "---",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}