import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const QontaApp());
}

// --- COLORES DE LA MARCA ---
class QontaColors {
  static const Color primaryBlue = Color(0xFF0D47A1); // Azul oscuro
  static const Color cardBlue = Color(0xFF1565C0);    // Azul botones
  static const Color accentYellow = Color(0xFFFFA000); // Mostaza/Amarillo
  static const Color backgroundBlue = Color(0xFF0D47A1); 
}

class QontaApp extends StatelessWidget {
  const QontaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Qonta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(seedColor: QontaColors.primaryBlue),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ⚠️⚠️⚠️ CAMBIA ESTO POR TU IP (ipconfig) ⚠️⚠️⚠️
  final String ipAddress = "192.168.X.X"; 
  
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;

  // --- LÓGICA DEL BACKEND (Cámara -> Python) ---
  Future<void> _procesarOperacion(bool esVenta) async {
    // 1. Cerrar el menú de selección si está abierto
    Navigator.of(context).pop(); 

    // 2. Abrir Cámara
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _isLoading = true);

    // 3. Preparar Envío
    String endpoint = esVenta ? "escanear-venta" : "escanear-compra";
    var uri = Uri.parse("http://$ipAddress:8000/$endpoint/");

    try {
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', photo.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        // 4. Mostrar Resultado en una ventana flotante
        _mostrarResultadoDialog(data['datos'], esVenta);
      } else {
        _mostrarSnackBar("Error del servidor: ${response.statusCode}", Colors.red);
      }
    } catch (e) {
      _mostrarSnackBar("Error de conexión. Revisa la IP.", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: color),
    );
  }

  // --- MENÚ PARA ELEGIR TIPO DE ESCANEO ---
  void _mostrarMenuEscaneo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 200,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("¿Qué deseas registrar?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _procesarOperacion(false), // Es Compra/Gasto
                      icon: const Icon(Icons.receipt_long),
                      label: const Text("GASTO"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QontaColors.accentYellow,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _procesarOperacion(true), // Es Venta
                      icon: const Icon(Icons.attach_money),
                      label: const Text("VENTA"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: QontaColors.cardBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  // --- DIALOGO DE RESULTADO (TICKET) ---
  void _mostrarResultadoDialog(Map<String, dynamic> datos, bool esVenta) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: EdgeInsets.zero,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: esVenta ? QontaColors.cardBlue : QontaColors.accentYellow,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white, size: 40),
                    const SizedBox(height: 5),
                    Text(
                      esVenta ? "VENTA REGISTRADA" : "GASTO REGISTRADO",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    )
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoRow("Fecha", datos['fecha_emision']),
                    _infoRow("RUC/Doc", esVenta ? datos['cliente_nro_doc'] : datos['proveedor_ruc']),
                    _infoRow("Nombre", esVenta ? datos['cliente_razon_social'] : datos['proveedor_razon_social']),
                    const Divider(),
                    const Text("TOTAL", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("S/ ${datos['monto_total']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 15),
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cerrar"),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, dynamic val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(child: Text(val?.toString() ?? "-", textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QontaColors.backgroundBlue,
      // --- BOTÓN FLOTANTE CON FUNCIONALIDAD ---
      floatingActionButton: Container(
        height: 70, width: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: FloatingActionButton(
          onPressed: _isLoading ? null : _mostrarMenuEscaneo, // <--- AQUI ESTÁ LA MAGIA
          backgroundColor: QontaColors.cardBlue,
          elevation: 0,
          shape: const CircleBorder(),
          child: _isLoading 
            ? const CircularProgressIndicator(color: Colors.white)
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.document_scanner_outlined, size: 28, color: Colors.white),
                  Text("Escanear", style: TextStyle(fontSize: 8, color: Colors.white))
                ],
              ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: _buildBottomAppBar(),

      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(), // HEADER CORREGIDO
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Estado de la empresa", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: QontaColors.primaryBlue)),
                          Icon(Icons.notifications_none, color: QontaColors.accentYellow),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildCompanyStatusCard(), // TARJETA CORREGIDA
                      const SizedBox(height: 25),
                      _buildSectionHeader("Ingresos", Icons.arrow_circle_up, QontaColors.cardBlue),
                      const SizedBox(height: 10),
                      // Datos de ejemplo
                      _TransactionItem(type: "B", title: "Boleta - Miguel Torres", amount: "S/ 150.00", color: QontaColors.cardBlue),
                      const SizedBox(height: 10),
                      _TransactionItem(type: "F", title: "Factura - Mevascorp", amount: "S/ 365.00", color: QontaColors.cardBlue),
                      const SizedBox(height: 10),
                      _buildSectionHeader("Egresos", Icons.arrow_circle_down, QontaColors.accentYellow),
                      const SizedBox(height: 10),
                      _TransactionItem(type: "F", title: "Factura - Pulisac", amount: "S/ 150.00", color: QontaColors.accentYellow),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE UI (Corregidos sin imagenes externas) ---
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // LOGO (Este si debe existir en assets/logo.png)
          SizedBox(
            height: 160,
            child: Image.asset('assets/logo.png', fit: BoxFit.contain, 
              errorBuilder: (c,o,s) => const Text("Qonta", style: TextStyle(color: Colors.white, fontSize: 24))), 
          ),
          Row(
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("Bienvenido", style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text("Oscar", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Chip(
                    label: Text("Basic", style: TextStyle(color: Colors.white, fontSize: 10)),
                    backgroundColor: QontaColors.accentYellow,
                    padding: EdgeInsets.zero,
                    labelPadding: EdgeInsets.symmetric(horizontal: 8, vertical: -4),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide.none,
                    shape: StadiumBorder(),
                  )
                ],
              ),
              const SizedBox(width: 10),
              // AVATAR (Ahora es un Icono, no pide imagen)
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  border: Border.all(color: QontaColors.accentYellow, width: 2),
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white24,
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 30),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCompanyStatusCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 3))],
        border: Border.all(color: Colors.grey.shade200)
      ),
      child: Row(
        children: [
          // LOGO EMPRESA (Ahora es un Icono)
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.yellow[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.store_mall_directory, color: Colors.black87, size: 30),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Mi Empresa", style: TextStyle(fontWeight: FontWeight.bold, height: 1.1)),
                Text("Arequipa", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Utilidad Neta", style: TextStyle(color: QontaColors.primaryBlue, fontWeight: FontWeight.bold)),
              Text("S/ 5,845.20", style: TextStyle(color: QontaColors.primaryBlue, fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(width: 5),
        Icon(icon, color: color, size: 20),
      ],
    );
  }

  Widget _buildBottomAppBar() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      color: QontaColors.primaryBlue,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          const Icon(Icons.home, color: QontaColors.accentYellow, size: 28),
          const Icon(Icons.menu_book, color: Colors.white, size: 28),
          const SizedBox(width: 40), 
          const Icon(Icons.groups, color: Colors.white, size: 28),
          const Icon(Icons.bar_chart, color: Colors.white, size: 28),
        ],
      ),
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final String type;
  final String title;
  final String amount;
  final Color color;

  const _TransactionItem({required this.type, required this.title, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Container(
            width: 35, height: 35,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), borderRadius: BorderRadius.circular(8)),
            child: Text(type, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
          Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}