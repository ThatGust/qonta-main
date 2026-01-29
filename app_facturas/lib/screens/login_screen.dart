import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final String ipAddress = "192.168.0.2";

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();

  bool _isObscured = true;
  bool _isLoading = false;
  bool _isRememberedUser = false;
  String _nombreMostrado = "";
  final LocalAuthentication auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _verificarEstadoInicial();
  }

  Future<void> _verificarEstadoInicial() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString('display_name_confirmed');
    String? lastEmail = prefs.getString('last_logged_user');

    setState(() {
      if (savedName != null && lastEmail != null) {
        _isRememberedUser = true;
        _nombreMostrado = savedName;
        _emailController.text = lastEmail;
      } else {
        _isRememberedUser = false;
      }
    });
  }

  void _cambiarDeUsuario() {
    setState(() {
      _isRememberedUser = false;
      _emailController.clear();
      _passController.clear();
    });
  }

  Future<void> _autenticarConHuella() async {
    if (!_isRememberedUser) return;

    try {
      bool authenticated = await auth.authenticate(
        localizedReason: 'Ingresa a tu cuenta',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (authenticated) {
        _passController.text = "123456";
        _realizarLogin();
      }
    } catch (e) {
      print("Error biometría: $e");
    }
  }

  Future<void> _realizarLogin() async {
    setState(() => _isLoading = true);
    try {
      var url = Uri.parse("http://$ipAddress:8000/login/");
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "email": _emailController.text.trim(),
          "password": _passController.text,
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        // Lógica de racha
        await _procesarLogicaNombre(
          data['usuario']['nombre'],
          data['usuario']['email'],
        );

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              userId: data['usuario']['id'],
              userName: data['usuario']['nombre'],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Credenciales incorrectas")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _procesarLogicaNombre(
    String nombreReal,
    String emailActual,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    String? ultimoUsuario = prefs.getString('last_logged_user');
    int racha = prefs.getInt('login_streak') ?? 0;

    if (ultimoUsuario == emailActual) {
      racha++;
    } else {
      racha = 1;
      await prefs.remove('display_name_confirmed');
    }

    await prefs.setInt('login_streak', racha);
    await prefs.setString('last_logged_user', emailActual);

    if (racha >= 3) {
      await prefs.setString('display_name_confirmed', nombreReal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // 1. FONDO
          Container(
            height: double.infinity,
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1565C0),
                  Color(0xFF0D47A1),
                  Color(0xFF002171),
                ],
              ),
            ),
          ),

          // 2. MONTAÑAS
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/mountains.png',
                errorBuilder: (c, o, s) => const SizedBox(),
              ),
            ),
          ),

          // 3. CONTENIDO
          SafeArea(
            child: Column(
              children: [
                // --- ENCABEZADO CORREGIDO ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ), // Más margen lateral
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment
                        .center, // ESTO ALINEA LOGO Y BOTÓN AL CENTRO
                    children: [
                      // Logo
                      SizedBox(
                        height: 100, // Altura controlada
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.fitHeight,
                          alignment: Alignment.centerLeft,
                          errorBuilder: (c, o, s) => const Text(
                            "Qonta",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Botón Otro Usuario
                      if (_isRememberedUser)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, // Un poco más ancho
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                0.2,
                              ), // Transparencia más suave
                              borderRadius: BorderRadius.circular(
                                30,
                              ), // Más redondeado
                            ),
                            child: Row(
                              children: const [
                                Text(
                                  "Otro usuario",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(
                                  Icons.person_add_alt_1_outlined,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // --- CONTENIDO CON SCROLL ---
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            // Esto obliga a la columna a ocupar al menos toda la altura disponible
                            minHeight: constraints.maxHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
                            child: Column(
                              // "spaceBetween" empuja el primer hijo arriba y el último abajo
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // A. GRUPO SUPERIOR (Textos e Iconos)
                                Column(
                                  children: [
                                    const SizedBox(height: 20),
                                    if (_isRememberedUser) ...[
                                      const Text(
                                        "Hola de nuevo",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 22,
                                        ),
                                      ),
                                      Text(
                                        _nombreMostrado,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: QontaColors.accentYellow,
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ] else ...[
                                      const Text(
                                        "Bienvenido/a",
                                        style: TextStyle(
                                          color: QontaColors.accentYellow,
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 15),

                                    if (_isRememberedUser)
                                      const Text(
                                        "¿Qué deseas hacer?",
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                    const SizedBox(height: 30),

                                    if (_isRememberedUser)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          _buildIcon(Icons.menu_book, "Libros"),
                                          const SizedBox(width: 25),
                                          _buildIcon(
                                            Icons.document_scanner_outlined,
                                            "Escanear",
                                            isActive: true,
                                          ),
                                          const SizedBox(width: 25),
                                          _buildIcon(
                                            Icons.bar_chart,
                                            "Informes",
                                          ),
                                        ],
                                      ),

                                    // Un espacio extra por seguridad visual
                                    const SizedBox(height: 20),
                                  ],
                                ),

                                // B. GRUPO INFERIOR (Tarjeta de Login)
                                // Al estar al final de la columna con "spaceBetween",
                                // se pegará al fondo
                                Container(
                                  margin: const EdgeInsets.only(
                                    bottom: 30,
                                  ), // Margen inferior aumentado
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 25,
                                    vertical: 30,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    children: [
                                      if (!_isRememberedUser) ...[
                                        TextField(
                                          controller: _emailController,
                                          decoration: InputDecoration(
                                            hintText: "Correo electrónico",
                                            prefixIcon: const Icon(
                                              Icons.email_outlined,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 18,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 15),
                                      ],
                                      TextField(
                                        controller: _passController,
                                        obscureText: _isObscured,
                                        decoration: InputDecoration(
                                          hintText: "Contraseña",
                                          prefixIcon: const Icon(
                                            Icons.lock_outline,
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _isObscured
                                                  ? Icons.visibility_off
                                                  : Icons.visibility,
                                            ),
                                            onPressed: () => setState(
                                              () => _isObscured = !_isObscured,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 18,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              15,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SizedBox(
                                              height: 55,
                                              child: ElevatedButton(
                                                onPressed: _isLoading
                                                    ? null
                                                    : _realizarLogin,
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      QontaColors.accentYellow,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          15,
                                                        ),
                                                  ),
                                                ),
                                                child: _isLoading
                                                    ? const CircularProgressIndicator(
                                                        color: Colors.white,
                                                      )
                                                    : const Text(
                                                        "Ingresar",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                          ),
                                          if (_isRememberedUser) ...[
                                            const SizedBox(width: 15),
                                            IconButton(
                                              onPressed: _autenticarConHuella,
                                              icon: const Icon(
                                                Icons.fingerprint,
                                                size: 45,
                                                color: QontaColors.accentYellow,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 15),
                                      GestureDetector(
                                        onTap: () {},
                                        child: const Text(
                                          "¿Olvidaste tu clave?",
                                          style: TextStyle(
                                            color: QontaColors.primaryBlue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(IconData icon, String label, {bool isActive = false}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(
            18,
          ), // Más padding interno -> Bloque más grande
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? QontaColors.accentYellow : Colors.white30,
              width: 3,
            ), // Borde más grueso
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white, size: 40), // Icono más grande
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
