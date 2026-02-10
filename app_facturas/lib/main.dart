import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/company_screen.dart';
import 'screens/edit_record_screen.dart';
import 'screens/records_screen.dart';
import 'screens/reports_screen.dart';


void main() {
  runApp(const QontaApp());
}

class QontaColors {
  static const Color primaryBlue = Color(0xFF0D47A1);
  static const Color cardBlue = Color(0xFF1565C0);
  static const Color accentYellow = Color(0xFFFFA000);
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
  final String ipAddress = "192.168.0.2";

  bool _isLoading = false;
  bool _loadingDashboard = true;
  bool _isBalanceVisible = false;
  final ImagePicker _picker = ImagePicker();
  int _selectedIndex = 0;
  int _avatarVersion = DateTime.now().millisecondsSinceEpoch;

  String _nombreMostrar = "";
  String _nicknameMostrar = "";
  String _emailMostrar = "";

  String? _rutaAvatar;

  String? _rutaLogo;
  String _rucEmpresa = "";
  String _razonSocial = "";
  String _direccionEmpresa = "";
  int _logoVersion = DateTime.now().millisecondsSinceEpoch;

  List<dynamic> _ingresosRecientes = [];
  List<dynamic> _egresosRecientes = [];

  @override
  void initState() {
    super.initState();
    _nombreMostrar = widget.userName;
    _nicknameMostrar = widget.userName.split(' ').first;
    _cargarDatosDashboard();
    _cargarInfoUsuario();
  }

  Future<void> _cargarInfoUsuario() async {
    try {
      var uri = Uri.parse("http://$ipAddress:8000/usuario/${widget.userId}");
      var response = await http.get(uri);
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          if (data['foto_perfil'] != null) _rutaAvatar = data['foto_perfil'];
          if (data['nickname'] != null) _nicknameMostrar = data['nickname'];
          if (data['email'] != null) _emailMostrar = data['email'];

          if (data['logo_empresa'] != null) _rutaLogo = data['logo_empresa'];
          _rucEmpresa = data['ruc'] ?? "";
          _razonSocial = data['razon_social'] ?? "";
          _direccionEmpresa = data['direccion'] ?? "";
        });
      }
    } catch (e) {
      print("Error cargando usuario: $e");
    }
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
    setState(() => _selectedIndex = index);

    if (index == 1) {
      await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => RecordsScreen(ipAddress: ipAddress, userId: widget.userId))
      );
      _cargarDatosDashboard(); // Recargar al volver por si borraron algo
    } else if (index == 3) {
      await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ReportsScreen(ipAddress: ipAddress, userId: widget.userId))
      );
    }

    if (mounted) {
      setState(() => _selectedIndex = 0);
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
                      onPressed: () => _procesarOperacion(false),
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
                      onPressed: () => _procesarOperacion(true),
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
            colors: [Color(0xFF0A5FE0), Color(0xFF1543B3), Color(0xFF222382)],
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
                        const Text("Estado de la empresa", style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: Colors.white)),

                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                _isBalanceVisible ? Icons.visibility : Icons.visibility_off,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isBalanceVisible = !_isBalanceVisible;
                                });
                              },
                            ),
                            const SizedBox(width: 5),

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
                      ],
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(35),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 5))],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35),
                          child: Column(
                            children: [
                              Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 20), child: _buildCompanyStatusCard()),
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

                                      if (_ingresosRecientes.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 20),
                                          child: Center(
                                            child: Text("No hay ingresos recientes", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                          ),
                                        )
                                      else
                                        ..._ingresosRecientes.map((item) => _TransactionItem(
                                          type: "B",
                                          title: item['titulo'] ?? "Venta",
                                          amount: _isBalanceVisible ? "S/ ${item['monto']}" : "S/ ****",
                                          color: Colors.blue.shade800,
                                        )),

                                      if (_ingresosRecientes.isNotEmpty)
                                        const Center(child: Text("Ver todos", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),

                                      const SizedBox(height: 20),

                                      _buildSectionHeader("Egresos", Icons.arrow_downward, Colors.orange),
                                      const SizedBox(height: 10),

                                      if (_egresosRecientes.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 20),
                                          child: Center(
                                            child: Text("No hay gastos recientes", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                                          ),
                                        )
                                      else
                                        ..._egresosRecientes.map((item) => _TransactionItem(
                                          type: "F",
                                          title: item['titulo'] ?? "Gasto",
                                          amount: _isBalanceVisible ? "S/ ${item['monto']}" : "S/ ****",
                                          color: Colors.orange,
                                        )),

                                      if (_egresosRecientes.isNotEmpty)
                                        const Center(child: Text("Ver todos", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold))),

                                      const SizedBox(height: 100),
                                    ],
                                  ),
                                ),
                              ),
                              _buildBottomAppBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: -45, left: 20,
                child: SizedBox(
                  height: 160,
                  child: Image.asset('assets/logo.png', fit: BoxFit.contain, errorBuilder: (c, o, s) => const Text("Qonta", style: TextStyle(color: Colors.white, fontSize: 24))),
                ),
              ),
              Positioned(
                bottom: 35,
                child: Container(
                  height: 90, width: 90,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                  child: FloatingActionButton(
                    onPressed: _isLoading ? null : _mostrarMenuEscaneo,
                    backgroundColor: Colors.blue.shade600,
                    elevation: 10,
                    shape: const CircleBorder(),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.document_scanner_outlined, size: 38, color: Colors.white), Text("Escanear", style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))]),
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
    ImageProvider imagenPerfil;
    if (_rutaAvatar != null && _rutaAvatar!.isNotEmpty && !_rutaAvatar!.contains('default_avatar')) {
      imagenPerfil = NetworkImage("http://$ipAddress:8000/static/$_rutaAvatar?v=$_avatarVersion");
    } else {
      imagenPerfil = const AssetImage('assets/avatar_default.png');
    }

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
                    const Text("Bienvenido", style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.0)),
                    Text(_nicknameMostrar, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.1)),
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(color: QontaColors.accentYellow, borderRadius: BorderRadius.circular(10)),
                      child: const Text("Basic", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 10),

              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'logout':
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                      );
                      break;

                    case 'profile':
                      final resultProfile = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProfileScreen(
                            userId: widget.userId,
                            ipAddress: ipAddress,
                            currentName: _nombreMostrar,
                            currentNickname: _nicknameMostrar,
                            currentEmail: _emailMostrar,
                            currentAvatar: _rutaAvatar,
                          ),
                        ),
                      );

                      if (resultProfile != null && resultProfile is Map) {
                        setState(() {
                          if (resultProfile['nombre'] != null) _nombreMostrar = resultProfile['nombre'];
                          if (resultProfile['nickname'] != null) _nicknameMostrar = resultProfile['nickname'];
                          if (resultProfile['avatar'] != null) {
                            _rutaAvatar = resultProfile['avatar'];
                            _avatarVersion = DateTime.now().millisecondsSinceEpoch;
                          }
                        });
                      }
                      break;

                    case 'company':
                      final resultCompany = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompanyScreen(
                            userId: widget.userId,
                            ipAddress: ipAddress,
                            currentRuc: _rucEmpresa,
                            currentRazon: _razonSocial,
                            currentDireccion: _direccionEmpresa,
                            currentLogo: _rutaLogo,
                          ),
                        ),
                      );

                      if (resultCompany != null && resultCompany is Map) {
                        setState(() {
                          if (resultCompany['logo'] != null) {
                            _rutaLogo = resultCompany['logo'];
                            _logoVersion = DateTime.now().millisecondsSinceEpoch;
                          }
                          if (resultCompany['razon'] != null) _razonSocial = resultCompany['razon'];
                        });
                      }
                      break;
                  }
                },
                offset: const Offset(0, 75),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    height: 30,
                    value: 'profile',
                    child: Row(children: [
                      Icon(Icons.person, color: QontaColors.primaryBlue, size: 20),
                      SizedBox(width: 10),
                      Text("Mi Perfil", style: TextStyle(fontWeight: FontWeight.w500))
                    ]),
                  ),
                  const PopupMenuItem(
                    height: 30,
                    value: 'company',
                    child: Row(children: [
                      Icon(Icons.business, color: QontaColors.primaryBlue, size: 20),
                      SizedBox(width: 10),
                      Text("Mi Empresa", style: TextStyle(fontWeight: FontWeight.w500))
                    ]),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    height: 30,
                    value: 'logout',
                    child: Row(children: [
                      Icon(Icons.logout, color: Colors.red, size: 15),
                      SizedBox(width: 10),
                      Text("Cerrar Sesión", style: TextStyle(fontWeight: FontWeight.w500))
                    ]),
                  ),
                ],
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: QontaColors.accentYellow, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: imagenPerfil,
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

    ImageProvider logoImage;
    if (_rutaLogo != null && _rutaLogo!.isNotEmpty && !_rutaLogo!.contains('default')) {
      logoImage = NetworkImage("http://$ipAddress:8000/static/$_rutaLogo?v=$_logoVersion");
    } else {
      logoImage = const AssetImage('assets/logo_placeholder.png');
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(color: Colors.white),
      child: Row(
        children: [

          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              image: _rutaLogo != null && !_rutaLogo!.contains('default')
                  ? DecorationImage(image: logoImage, fit: BoxFit.cover)
                  : null,
            ),
            child: (_rutaLogo == null || _rutaLogo!.contains('default'))
                ? Icon(Icons.store_mall_directory, color: QontaColors.primaryBlue, size: 35)
                : null,          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Flujo de Caja", style: TextStyle(color: QontaColors.primaryBlue, fontWeight: FontWeight.bold)),

              Text(
                  _isBalanceVisible
                      ? "S/ ${utilidad.toStringAsFixed(2)}"
                      : "S/ ****",
                  style: const TextStyle(color: QontaColors.primaryBlue, fontSize: 20, fontWeight: FontWeight.bold)
              ),
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