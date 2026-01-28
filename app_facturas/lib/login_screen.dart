import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'main.dart'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ⚠️ IP DEL BACKEND 
  final String ipAddress = "192.168.0.2"; 
  
  // Controladores
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  
  bool _isObscured = true;
  bool _isLoading = false;
  
  // Estado de la Vista
  bool _isRememberedUser = false; // ¿Mostramos vista de usuario recordado?
  String _nombreMostrado = ""; 
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _verificarEstadoInicial();
    _verificarBiometria();
  }

  // 1. Determinar si mostramos "Hola de nuevo" o "Bienvenido"
  Future<void> _verificarEstadoInicial() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('display_name_confirmed');
    String? lastEmail = prefs.getString('last_logged_user');

    setState(() {
      if (savedName != null && lastEmail != null) {
        // CASO: Usuario Recordado (Racha > 3)
        _isRememberedUser = true;
        _nombreMostrado = savedName;
        _emailController.text = lastEmail; // Pre-llenamos el correo internamente
      } else {
        // CASO: Nuevo Usuario o Racha baja
        _isRememberedUser = false;
      }
    });
  }

  // Acción para el botón de "Cambiar Usuario"
  void _cambiarDeUsuario() {
    setState(() {
      _isRememberedUser = false; // Cambiamos a vista de "Desde 0"
      _emailController.clear();  // Limpiamos correo
      _passController.clear();   // Limpiamos clave
    });
  }

  Future<void> _verificarBiometria() async {
    bool canCheckBiometrics = await auth.canCheckBiometrics;
    if (canCheckBiometrics && _isRememberedUser) {
       // Opcional: Podrías activar huella automática aquí si es usuario recordado
    }
  }

  Future<void> _autenticarConHuella() async {
    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Usa tu huella para ingresar a Qonta',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated) {
        // Simulamos login exitoso (En prod usarías tokens seguros)
        _passController.text = "123456"; 
        _realizarLogin();
      }
    } catch (e) {
      print("Error biometría: $e");
    }
  }

  Future<void> _realizarLogin() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      _mostrarError("Completa todos los campos");
      return;
    }

    setState(() => _isLoading = true);

    try {
      var url = Uri.parse("http://$ipAddress:8000/login/");
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "email": _emailController.text.trim(), // Usamos el del controlador
          "password": _passController.text
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        String nombreReal = data['usuario']['nombre'];
        
        // Procesamos la lógica de la racha (3 veces)
        await _procesarLogicaNombre(nombreReal, _emailController.text.trim());
        
        if (!mounted) return;
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (context) => const DashboardScreen())
        );
      } else {
        _mostrarError("Credenciales incorrectas");
      }
    } catch (e) {
      _mostrarError("Error de conexión: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _procesarLogicaNombre(String nombreReal, String emailActual) async {
    final prefs = await SharedPreferences.getInstance();
    
    String? ultimoUsuario = prefs.getString('last_logged_user');
    int racha = prefs.getInt('login_streak') ?? 0;

    if (ultimoUsuario == emailActual) {
      racha++; // Mismo usuario, aumentamos racha
    } else {
      racha = 1; // Usuario diferente, reiniciamos
      // Si cambia de usuario, borramos el "nombre confirmado" anterior
      await prefs.remove('display_name_confirmed'); 
    }

    await prefs.setInt('login_streak', racha);
    await prefs.setString('last_logged_user', emailActual);

    // Si la racha llega a 3, guardamos el nombre para mostrarlo en el futuro
    if (racha >= 3) {
      await prefs.setString('display_name_confirmed', nombreReal);
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, 
      body: Stack(
        children: [
          // 1. FONDO
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1), Color(0xFF002171)],
              ),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Opacity(
              opacity: 0.2,
              child: Image.asset('assets/mountains.png', errorBuilder: (c,o,s)=>const SizedBox()), 
            ),
          ),

          // 2. BOTÓN "CAMBIAR USUARIO" (Solo visible si hay usuario recordado)
          if (_isRememberedUser)
            Positioned(
              top: 50,
              right: 20,
              child: GestureDetector(
                onTap: _cambiarDeUsuario,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30)
                  ),
                  child: Row(
                    children: const [
                      Text("Otro usuario", style: TextStyle(color: Colors.white, fontSize: 12)),
                      SizedBox(width: 5),
                      Icon(Icons.person_add_alt_1_outlined, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ),
            ),

          // 3. CONTENIDO PRINCIPAL
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          const Text("Qonta", 
                            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2)
                          ),
                          
                          const Spacer(flex: 2),

                          // --- TEXTOS DE BIENVENIDA DINÁMICOS ---
                          if (_isRememberedUser) ...[
                            // MODO RECORDADO: "Hola de nuevo Oscar"
                            const Text("Hola de nuevo", style: TextStyle(color: Colors.white70, fontSize: 18)),
                            Text(_nombreMostrado, 
                              style: const TextStyle(color: QontaColors.accentYellow, fontSize: 32, fontWeight: FontWeight.bold)
                            ),
                          ] else ...[
                            // MODO NUEVO: "Bienvenido/a" (Grande)
                            const Text("Bienvenido/a", 
                              style: TextStyle(color: QontaColors.accentYellow, fontSize: 36, fontWeight: FontWeight.bold)
                            ),
                          ],
                          
                          const SizedBox(height: 10),
                          // Si es nuevo usuario, no preguntamos "¿Qué deseas hacer?" aún, porque no está logueado
                          if (_isRememberedUser)
                            const Text("¿Qué deseas hacer?", 
                              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                            ),

                          const SizedBox(height: 30),

                          // ICONOS (Solo visibles si es usuario recordado para decorar, o puedes quitarlos en modo nuevo)
                          // Para mantener el diseño limpio en "Bienvenido", los ocultaremos si es nuevo usuario
                          if (_isRememberedUser)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildQuickAction(Icons.menu_book, "Libros"),
                              const SizedBox(width: 25),
                              _buildQuickAction(Icons.document_scanner_outlined, "Escanear", isActive: true),
                              const SizedBox(width: 25),
                              _buildQuickAction(Icons.bar_chart, "Informes"),
                            ],
                          ),

                          const Spacer(flex: 3),

                          // 4. TARJETA DE LOGIN
                          Container(
                            padding: const EdgeInsets.all(30),
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // CAMPO DE CORREO (Solo visible si NO es usuario recordado)
                                if (!_isRememberedUser) ...[
                                  TextField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      hintText: "Correo electrónico",
                                      prefixIcon: const Icon(Icons.email_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                      contentPadding: const EdgeInsets.symmetric(vertical: 15)
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                ],

                                // CAMPO CONTRASEÑA (Siempre visible)
                                TextField(
                                  controller: _passController,
                                  obscureText: _isObscured,
                                  decoration: InputDecoration(
                                    hintText: "Contraseña",
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(_isObscured ? Icons.visibility_off : Icons.visibility),
                                      onPressed: () => setState(() => _isObscured = !_isObscured),
                                    ),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                  ),
                                ),
                                
                                const SizedBox(height: 20),

                                // BOTÓN INGRESAR
                                SizedBox(
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _realizarLogin,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: QontaColors.accentYellow,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                    child: _isLoading 
                                      ? const CircularProgressIndicator(color: Colors.white)
                                      : const Text("Ingresar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ),
                                ),

                                const SizedBox(height: 20),
                                
                                // OPCIONES EXTRA
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Huella solo si es usuario recordado (porque necesitamos saber QUIÉN es para validar su huella contra la BD hipotética)
                                    _isRememberedUser 
                                      ? IconButton(
                                          onPressed: _autenticarConHuella,
                                          icon: const Icon(Icons.fingerprint, size: 40, color: QontaColors.primaryBlue),
                                        )
                                      : const SizedBox(width: 40), // Espacio vacío para balancear
                                    
                                    TextButton(
                                      onPressed: () {}, 
                                      child: const Text("¿Olvidaste tu clave?", style: TextStyle(color: QontaColors.primaryBlue))
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction(IconData icon, String label, {bool isActive = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.transparent,
            border: Border.all(color: isActive ? QontaColors.accentYellow : Colors.white30, width: 2),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12))
      ],
    );
  }
}