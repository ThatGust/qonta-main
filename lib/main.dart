import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';


void main() {
  runApp(const QontaApp());
}

class QontaColors {
  static const Color primaryBlue = Color(0xFF0D47A1);
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
  final int userId;
  final String userName;

  const DashboardScreen({super.key, required this.userId, required this.userName});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final String ipAddress = "192.168.0.4";

  bool _isLoading = false;
  bool _loadingDashboard = true;
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;

  String _nombreMostrar = "";
  String _nicknameMostrar = "";

  List<dynamic> _ingresosRecientes = [];
  List<dynamic> _egresosRecientes = [];

  @override
  void initState() {
    super.initState();
    _nombreMostrar = widget.userName;
    _nicknameMostrar = widget.userName.split(' ').first;
    _cargarDatosDashboard();
  }

  Future<void> _cargarDatosDashboard() async {
    setState(() => _loadingDashboard = true);
    try {
      var uriVentas = Uri.parse("http://$ipAddress:8000/obtener-registros/ventas?user_id=${widget.userId}");
      var resVentas = await http.get(uriVentas);

      var uriCompras = Uri.parse("http://$ipAddress:8000/obtener-registros/compras?user_id=${widget.userId}");
      var resCompras = await http.get(uriCompras);

      if (resVentas.statusCode == 200 && resCompras.statusCode == 200) {
        var dataVentas = json.decode(resVentas.body);
        var dataCompras = json.decode(resCompras.body);

        setState(() {
          _ingresosRecientes = (dataVentas['datos'] as List).take(2).toList();
          _egresosRecientes = (dataCompras['datos'] as List).take(2).toList();
          _loadingDashboard = false;
        });
      }
    } catch (e) {
      print("Error cargando dashboard: $e");
      setState(() => _loadingDashboard = false);
    }
  }

  void _onNavTap(int index) async {
    setState(() => _selectedIndex = index); // Actualiza la selección visual

    if (index == 1) { // Libros
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => RecordsScreen(ipAddress: ipAddress, userId: widget.userId)
          )
      );
      _cargarDatosDashboard();
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

      request.fields['user_id'] = widget.userId.toString();

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
                            builder: (context) => EditarDatosScreen(datos: datos, esVenta: esVenta, ipAddress: ipAddress, userId: widget.userId),
                          ),
                        );
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF0A5FE0), // Azul profundo inicial
              Color(0xFF1543B3), // Azul más oscuro de transición
              Color(0xFF222382), // Tono violeta/azul real final
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Column(
                children: [
                  _buildHeader(),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Estado de la empresa",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white, // Blanco para resaltar sobre el degradado
                          ),
                        ),
                        Stack(
                          children: [
                            const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                            Positioned(
                              right: 0, top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                                child: const Text('1', style: TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                              ),
                            )
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Contenedor principal flotante
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 5)
                            )
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                                child: _buildCompanyStatusCard(),
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.symmetric(horizontal: 20),
                                  physics: const BouncingScrollPhysics(),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 0),
                                      _buildSectionHeader("Ingresos", Icons.arrow_upward, Colors.blue.shade800),
                                      const SizedBox(height: 10),
                                      ..._ingresosRecientes.map((item) => _TransactionItem(
                                        type: "B", // Icono tipo Boleta
                                        title: item['titulo'] ?? "Venta",
                                        amount: "S/ ${item['monto']}",
                                        color: Colors.blue.shade800,
                                      )),
                                      const Center(child: Text("Ver todos", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),

                                      const SizedBox(height: 20),
                                      _buildSectionHeader("Egresos", Icons.arrow_downward, Colors.orange),
                                      const SizedBox(height: 10),
                                      ..._egresosRecientes.map((item) => _TransactionItem(
                                        type: "F", // Icono tipo Factura
                                        title: item['titulo'] ?? "Gasto",
                                        amount: "S/ ${item['monto']}",
                                        color: Colors.orange,
                                      )),
                                      const Center(child: Text("Ver todos", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),
                                      const SizedBox(height: 100), // Espacio para no chocar con el botón
                                    ],
                                  ),
                                ),
                              ),
                              _buildBottomAppBar(), // Barra de navegación dentro del contenedor
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              Positioned(
                top: -45,
                left: 20,
                child: SizedBox(
                  height: 160, // Tamaño aumentado para que sea "más grande"
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (c, o, s) => const Text("Qonta", style: TextStyle(color: Colors.white, fontSize: 24)),
                  ),
                ),
              ),

              Positioned(
                bottom: 35, // Elevación controlada
                child: Container(
                  height: 90, width: 90, // Tamaño aumentado para relevancia
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 5), // Borde blanco grueso
                  ),
                  child: FloatingActionButton(
                    onPressed: _isLoading ? null : _mostrarMenuEscaneo,
                    backgroundColor: Colors.blue.shade600,
                    elevation: 10,
                    shape: const CircleBorder(),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.document_scanner_outlined, size: 38, color: Colors.white),
                        Text("Escanear", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Row(
            children: [
              IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Bienvenido",
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.0)),
                    Text(
                        _nicknameMostrar,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            height: 1.1
                        )
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: QontaColors.accentYellow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        "Basic",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),

              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'logout') {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                          (route) => false,
                    );
                  } else if (value == 'profile') {
                    final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ProfileScreen(
                                userId: widget.userId, // <--- ESTO FALTABA
                                ipAddress: ipAddress,  // <--- ESTO FALTABA
                                currentName: _nombreMostrar,
                                currentNickname: _nicknameMostrar,
                                currentEmail: "usuario@ejemplo.com"
                            )
                        )
                    );

                    if (result != null && result is Map) {
                      setState(() {
                        if (result['nombre'] != null) _nombreMostrar = result['nombre'];
                        if (result['nickname'] != null && result['nickname'].toString().isNotEmpty) {
                          _nicknameMostrar = result['nickname'];
                        }
                      });
                    }
                  }
                },
                // -------------------------------------
                offset: const Offset(0, 75),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    height: 30,
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, color: QontaColors.primaryBlue, size: 20),
                        SizedBox(width: 10),
                        Text("Mi Perfil", style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    height: 30,
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.red, size: 15),
                        SizedBox(width: 10),
                        Text("Cerrar Sesión", style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: QontaColors.accentYellow, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    image: const DecorationImage(
                      image: AssetImage('assets/avatar_default.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = _selectedIndex == index;
    Color activeColor = QontaColors.accentYellow;
    Color inactiveColor = Colors.white;

    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(5)),
            ),
          ),
          const SizedBox(height: 5),
          Icon(
            icon,
            color: isSelected ? activeColor : inactiveColor,
            size: 26,
          ),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? activeColor : inactiveColor,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 5),
        ],
      ),
    );
  }

  Widget _buildCompanyStatusCard() {
    double totalIngresos = _ingresosRecientes.fold(0, (sum, item) => sum + (item['monto'] ?? 0));
    double totalEgresos = _egresosRecientes.fold(0, (sum, item) => sum + (item['monto'] ?? 0));
    double utilidad = totalIngresos - totalEgresos;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Container(
        height: 70,
        decoration: BoxDecoration(
          color: QontaColors.primaryBlue,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home, "Inicio"),
            _buildNavItem(1, Icons.menu_book, "Libros"),
            const SizedBox(width: 60),
            _buildNavItem(2, Icons.groups, "Planilla"),
            _buildNavItem(3, Icons.bar_chart, "Informes"),
          ],
        ),
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

class RecordsScreen extends StatefulWidget {
  final String ipAddress;
  final int userId;
  const RecordsScreen({super.key, required this.ipAddress, required this.userId});

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
      var uri = Uri.parse("http://${widget.ipAddress}:8000/obtener-registros/$_filtroTipo?user_id=${widget.userId}");
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
  final int userId;

  const EditarDatosScreen({super.key, required this.datos, required this.esVenta, required this.ipAddress, required this.userId});

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
      "user_id": widget.userId,
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