import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'login_screen.dart';

void main() {
  runApp(const QontaApp());
}

class QontaColors {
  static const Color primaryBlue = Color(0xFF0D47A1); // Azul oscuro
  static const Color cardBlue = Color(0xFF1565C0);    // Azul 
  static const Color accentYellow = Color(0xFFFFA000); // Mostaza semi-amarillo
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
      home: const LoginScreen(), 
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ⚠️ Asegúrate que esta IP sea la correcta
  final String ipAddress = "192.168.0.2"; 
  
  bool _isLoading = false;
  bool _loadingDashboard = true; // Para saber si estamos cargando los datos del dashboard
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;

  // Listas para almacenar los datos reales
  List<dynamic> _ingresosRecientes = [];
  List<dynamic> _egresosRecientes = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosDashboard(); // Cargar datos al iniciar
  }

  // Función para traer datos del backend (Ventas y Compras)
  Future<void> _cargarDatosDashboard() async {
    setState(() => _loadingDashboard = true);
    try {
      // 1. Traer Ventas (Ingresos)
      var uriVentas = Uri.parse("http://$ipAddress:8000/obtener-registros/ventas");
      var resVentas = await http.get(uriVentas);
      
      // 2. Traer Compras (Egresos)
      var uriCompras = Uri.parse("http://$ipAddress:8000/obtener-registros/compras");
      var resCompras = await http.get(uriCompras);

      if (resVentas.statusCode == 200 && resCompras.statusCode == 200) {
        var dataVentas = json.decode(resVentas.body);
        var dataCompras = json.decode(resCompras.body);

        setState(() {
          // Tomamos solo los últimos 3 registros para el dashboard
          _ingresosRecientes = (dataVentas['datos'] as List).take(3).toList();
          _egresosRecientes = (dataCompras['datos'] as List).take(3).toList();
          _loadingDashboard = false;
        });
      }
    } catch (e) {
      print("Error cargando dashboard: $e");
      setState(() => _loadingDashboard = false);
    }
  }

  void _onNavTap(int index) async {
    if (index == 1) { 
      // Si volvemos de la pantalla de registros, recargamos el dashboard por si hubo cambios
      await Navigator.push(
        context, 
        MaterialPageRoute(
          builder: (context) => RecordsScreen(ipAddress: ipAddress) 
        ) 
      );
      _cargarDatosDashboard();
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _procesarOperacion(bool esVenta) async {
    Navigator.of(context).pop(); 

    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    setState(() => _isLoading = true);

    String endpoint = esVenta ? "escanear-venta" : "escanear-compra";
    var uri = Uri.parse("http://$ipAddress:8000/$endpoint/");

    try {
      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', photo.path));
      
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
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
                      onPressed: () => _procesarOperacion(false), // Compra/Gasto
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
                      onPressed: () => _procesarOperacion(true), // Venta
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

  void _mostrarResultadoDialog(Map<String, dynamic> datos, bool esVenta) {
    showDialog(
      context: context,
      barrierDismissible: false,
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
                      esVenta ? "VENTA DETECTADA" : "GASTO DETECTADO",
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
                    const Text("TOTAL DETECTADO", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("S/ ${datos['monto_total'] ?? datos['total_cp']}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 15, right: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditarDatosScreen(datos: datos, esVenta: esVenta, ipAddress: ipAddress),
                          ),
                        );
                        // Al volver de editar, recargamos el dashboard
                        _cargarDatosDashboard();
                      },
                      child: const Text(
                        "EDITAR / GUARDAR",
                        style: TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                    ),
                  ],
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
      floatingActionButton: Container(
        height: 70, width: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        child: FloatingActionButton(
          onPressed: _isLoading ? null : _mostrarMenuEscaneo,
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
            _buildHeader(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: _loadingDashboard 
                  ? const Center(child: CircularProgressIndicator()) 
                  : SingleChildScrollView(
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
                          _buildCompanyStatusCard(), 
                          const SizedBox(height: 25),
                          
                          // --- SECCIÓN INGRESOS (VENTAS) DINÁMICA ---
                          _buildSectionHeader("Ingresos Recientes", Icons.arrow_circle_up, QontaColors.cardBlue),
                          const SizedBox(height: 10),
                          if (_ingresosRecientes.isEmpty)
                             const Padding(padding: EdgeInsets.all(8.0), child: Text("No hay ingresos registrados", style: TextStyle(color: Colors.grey))),
                          ..._ingresosRecientes.map((item) => _TransactionItem(
                              type: "V", // Venta
                              title: item['titulo'] ?? "Venta",
                              amount: "S/ ${item['monto']}",
                              color: QontaColors.cardBlue,
                          )),

                          const SizedBox(height: 20),

                          // --- SECCIÓN EGRESOS (GASTOS) DINÁMICA ---
                          _buildSectionHeader("Egresos Recientes", Icons.arrow_circle_down, QontaColors.accentYellow),
                          const SizedBox(height: 10),
                          if (_egresosRecientes.isEmpty)
                             const Padding(padding: EdgeInsets.all(8.0), child: Text("No hay egresos registrados", style: TextStyle(color: Colors.grey))),
                          ..._egresosRecientes.map((item) => _TransactionItem(
                              type: "G", // Gasto
                              title: item['titulo'] ?? "Gasto",
                              amount: "S/ ${item['monto']}",
                              color: QontaColors.accentYellow,
                          )),
                          
                          // Espacio extra para que el botón flotante no tape el último item
                          const SizedBox(height: 60), 
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
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
    // Calculamos utilidad simple basada en lo que vemos (solo como ejemplo visual)
    double totalIngresos = _ingresosRecientes.fold(0, (sum, item) => sum + (item['monto'] ?? 0));
    double totalEgresos = _egresosRecientes.fold(0, (sum, item) => sum + (item['monto'] ?? 0));
    double utilidad = totalIngresos - totalEgresos;

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
                Text("Resumen Reciente", style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Flujo de Caja", style: TextStyle(color: QontaColors.primaryBlue, fontWeight: FontWeight.bold)),
              Text("S/ ${utilidad.toStringAsFixed(2)}", style: const TextStyle(color: QontaColors.primaryBlue, fontSize: 20, fontWeight: FontWeight.bold)),
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
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Icon(Icons.home, color: _selectedIndex == 0 ? QontaColors.accentYellow : Colors.white, size: 28),
            onPressed: () => _onNavTap(0),
          ),
          IconButton(
            icon: Icon(Icons.menu_book, color: _selectedIndex == 1 ? QontaColors.accentYellow : Colors.white, size: 28),
            onPressed: () => _onNavTap(1), 
          ),
          const SizedBox(width: 40), 
          IconButton(
            icon: const Icon(Icons.groups, color: Colors.white, size: 28),
            onPressed: () => _onNavTap(2),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white, size: 28),
            onPressed: () => _onNavTap(3),
          ),
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
      margin: const EdgeInsets.only(bottom: 10), // Margen añadido
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
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
          Text(amount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// --------------------------------------------------------
// PANTALLA DE "MIS REGISTROS" (Reutilizada con IP dinámica)
// --------------------------------------------------------
class RecordsScreen extends StatefulWidget {
  final String ipAddress;
  const RecordsScreen({super.key, required this.ipAddress});

  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  String _filtroTipo = "compras"; 
  List<dynamic> _registros = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarRegistros();
  }

  Future<void> _cargarRegistros() async {
    setState(() => _loading = true);
    try {
      var uri = Uri.parse("http://${widget.ipAddress}:8000/obtener-registros/$_filtroTipo");
      var response = await http.get(uri);
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          _registros = data['datos'];
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
      print("Error cargando registros: $e");
    }
  }

  void _mostrarDialogoEditar(Map<String, dynamic> item) {
    // Implementación simplificada para solo visualización en este ejemplo
    // Aquí iría tu lógica de edición existente
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Mis Registros", style: TextStyle(color: Colors.white)),
        backgroundColor: QontaColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Row(
              children: [
                _buildFilterChip("Gastos / Compras", "compras", Colors.orange),
                const SizedBox(width: 10),
                _buildFilterChip("Ventas / Ingresos", "ventas", Colors.blue),
              ],
            ),
          ),
          Expanded(
            child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _registros.isEmpty 
                ? const Center(child: Text("No hay registros aún"))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: _registros.length,
                    itemBuilder: (context, index) {
                      final item = _registros[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        child: ListTile(
                          leading: Container(
                            width: 50, height: 50, 
                            color: Colors.grey[200], 
                            child: const Icon(Icons.receipt)
                          ),
                          title: Text(item['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item['fecha']} • ${item['categoria'] ?? ''}"),
                          trailing: Text("S/ ${item['monto']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String valor, Color color) {
    bool selected = _filtroTipo == valor;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: color.withOpacity(0.2),
      labelStyle: TextStyle(color: selected ? color : Colors.grey),
      onSelected: (bool val) {
        if (val) {
          setState(() {
            _filtroTipo = valor;
            _cargarRegistros();
          });
        }
      },
    );
  }
}

// --------------------------------------------------------
// PANTALLA DE EDICIÓN (Logica de confirmación)
// --------------------------------------------------------
class EditarDatosScreen extends StatefulWidget {
  final Map<String, dynamic> datos;
  final bool esVenta;
  final String ipAddress;

  const EditarDatosScreen({super.key, required this.datos, required this.esVenta, required this.ipAddress});

  @override
  State<EditarDatosScreen> createState() => _EditarDatosScreenState();
}

class _EditarDatosScreenState extends State<EditarDatosScreen> {
  bool _isSaving = false; 

  late TextEditingController _rucController;
  late TextEditingController _nombreController;
  late TextEditingController _montoController;
  late TextEditingController _fechaController;
  late TextEditingController _docController;

  @override
  void initState() {
    super.initState();
    // Inicialización robusta para evitar nulos
    _rucController = TextEditingController(text: widget.esVenta 
        ? (widget.datos['cliente_nro_doc']?.toString() ?? "") 
        : (widget.datos['proveedor_ruc']?.toString() ?? ""));
    _nombreController = TextEditingController(text: widget.esVenta 
        ? (widget.datos['cliente_razon_social'] ?? "") 
        : (widget.datos['proveedor_razon_social'] ?? ""));
        
    // Manejar el monto que puede venir como 'monto_total' o 'total_cp'
    var monto = widget.datos['monto_total'] ?? widget.datos['total_cp'];
    _montoController = TextEditingController(text: monto?.toString() ?? "0.0");
    
    _fechaController = TextEditingController(text: widget.datos['fecha_emision'] ?? "");
    _docController = TextEditingController(text: "${widget.datos['serie'] ?? ''}-${widget.datos['numero'] ?? ''}");
  }

  @override
  void dispose() {
    _rucController.dispose();
    _nombreController.dispose();
    _montoController.dispose();
    _fechaController.dispose();
    _docController.dispose();
    super.dispose();
  }

  Future<void> _confirmarYGuardar() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);
    
    Map<String, dynamic> body = {
      "tipo": widget.esVenta ? "venta" : "compra",
      "datos": {
        "fecha_emision": _fechaController.text,
        "monto_total": double.tryParse(_montoController.text) ?? 0.0,
        "serie": _docController.text,
        if (widget.esVenta) "cliente_nro_doc": _rucController.text else "proveedor_ruc": _rucController.text,
        if (widget.esVenta) "cliente_razon_social": _nombreController.text else "proveedor_razon_social": _nombreController.text,
      }
    };

    try {
      var response = await http.post(
        Uri.parse("http://${widget.ipAddress}:8000/guardar-confirmado/"),
        headers: {"Content-Type": "application/json"},
        body: json.encode(body),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context); // Cierra pantalla de edición
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Datos guardados con éxito!"), backgroundColor: Colors.green),
        );
      } else {
        throw Exception("Error del servidor: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QontaColors.primaryBlue,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Editar Registro", style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text("Verifica los datos", 
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _confirmarYGuardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: QontaColors.accentYellow,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: _isSaving 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Confirmar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                )
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Detalles del Documento", 
                      style: const TextStyle(color: QontaColors.cardBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildEditField("RUC / Doc:", _rucController),
                    _buildEditField("Razón social / Nombre:", _nombreController),
                    _buildEditField("Monto Total (S/):", _montoController, isNumber: true),
                    _buildEditField("Fecha (DD/MM/YYYY):", _fechaController),
                    _buildEditField("Serie / Número:", _docController),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: QontaColors.cardBlue, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: QontaColors.accentYellow),
                borderRadius: BorderRadius.circular(25),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: QontaColors.cardBlue, width: 2),
                borderRadius: BorderRadius.circular(25),
              ),
            ),
          ),
        ],
      ),
    );
  }
}