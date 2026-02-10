import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final LocalAuthentication auth = LocalAuthentication();
  final TextEditingController _passController = TextEditingController();

  bool _isObscured = true;
  bool _isLoading = false;
  bool _isRememberedUser = false;

  final _storage = const FlutterSecureStorage();
  String _nombreMostrado = "";

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
        _nombreMostrado = savedName.split(' ').first;
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
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      if (!canAuthenticateWithBiometrics) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Tu dispositivo no soporta biometría o no está configurada")),
        );
        return;
      }

      bool authenticated = await auth.authenticate(
        localizedReason: 'Toca el sensor para ingresar a Qonta',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (authenticated) {
        String? storedPass = await _storage.read(key: 'user_password');

        if (storedPass != null && storedPass.isNotEmpty) {
          setState(() {
            _passController.text = storedPass;
          });
          _realizarLogin();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Por seguridad, ingresa tu contraseña manualmente una vez más.")),
          );
        }
      }
    } catch (e) {
      print("Error biometría: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error de autenticación: $e")),
      );
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

        await _storage.write(key: 'user_password', value: _passController.text);

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

    if (racha >= 1) {
      await prefs.setString('display_name_confirmed', nombreReal);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
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

          Positioned.fill(
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'assets/mountains.png',
                fit: BoxFit.cover,
                errorBuilder: (c, o, s) => const SizedBox(),
              ),
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            left: MediaQuery.of(context).viewInsets.bottom > 0 ? -150 : -20,
            top: MediaQuery.of(context).size.height * 0.45,
            child: Container(
                width: 100,
                height: 15,
                decoration: BoxDecoration(
                    color: QontaColors.accentYellow,
                    borderRadius: BorderRadius.circular(10)
                )
            ),
          ),

          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            right: MediaQuery.of(context).viewInsets.bottom > 0 ? -150 : -20,
            top: MediaQuery.of(context).size.height * 0.40,
            child: Container(
                width: 120,
                height: 15,
                decoration: BoxDecoration(
                    color: QontaColors.accentYellow,
                    borderRadius: BorderRadius.circular(10)
                )
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [


                      if (_isRememberedUser)

                        SizedBox(
                          height: 70,
                          width: 170,
                          child: OverflowBox(
                            maxHeight: 180,
                            maxWidth: 300,
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/logo.png',
                              height: 160,
                              fit: BoxFit.contain,
                              alignment: Alignment.centerLeft,
                              errorBuilder: (c, o, s) => const Text("Qonta", style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ),

                      if (_isRememberedUser)

                        Row(
                          children: [
                            SvgPicture.asset(
                              'assets/icons/whatsapp.svg',
                              height: 20,
                              width: 20,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),

                            const SizedBox(width: 15),

                            GestureDetector(
                              onTap: _cambiarDeUsuario,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Row(
                                  children: const [
                                    Text(
                                      "Otro usuario",
                                      style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.person_add_alt_1_outlined, color: Colors.white, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Column(
                        children: [
                          Builder(builder: (context) {
                            bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
                            return SizedBox(height: isKeyboardOpen ? 10 : 60);
                          }),

                          Column(
                            children: [
                              if (_isRememberedUser) ...[
                                const Text("Hola de nuevo", style: TextStyle(color: Colors.white70, fontSize: 22)),
                                Text(
                                  _nombreMostrado,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: QontaColors.accentYellow, fontSize: 40, fontWeight: FontWeight.bold),
                                ),
                              ] else ...[
                                Image.asset(
                                  'assets/logo.png',
                                  height: 250,
                                  fit: BoxFit.contain,
                                ),
                              ],

                              const SizedBox(height: 10),

                              if (_isRememberedUser) ...[
                                const Text(
                                  "¿Qué deseas hacer?",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 120),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildIcon(iconData: Icons.menu_book, label: "Libros"),
                                    const SizedBox(width: 40),
                                    _buildIcon(svgPath: 'assets/icons/scan.svg', label: "Escanear", isActive: true),
                                    const SizedBox(width: 40),
                                    _buildIcon(svgPath: 'assets/icons/graph.svg', label: "Informes"),
                                  ],
                                ),
                              ],
                            ],
                          ),

                          const SizedBox(height: 40),

                          Container(
                            margin: const EdgeInsets.only(bottom: 30),
                            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 5)),
                              ],
                            ),
                            child: Column(
                              children: [
                                if (!_isRememberedUser) ...[
                                  TextField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      hintText: "Correo electrónico",
                                      prefixIcon: const Icon(Icons.email_outlined),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                ],
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

                                if (!_isRememberedUser) ...[
                                  const SizedBox(height: 15),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 55,
                                    child: OutlinedButton(
                                      onPressed: () {},
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.asset('assets/icons/google.svg', height: 20),
                                          const SizedBox(width: 10),
                                          const Text("Ingresar con Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 20),

                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 55,
                                        child: ElevatedButton(
                                          onPressed: _isLoading ? null : _realizarLogin,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: QontaColors.accentYellow,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                          ),
                                          child: _isLoading
                                              ? const CircularProgressIndicator(color: Colors.white)
                                              : const Text("Ingresar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ),
                                    if (_isRememberedUser) ...[
                                      const SizedBox(width: 15),
                                      IconButton(
                                        onPressed: _autenticarConHuella,
                                        icon: const Icon(Icons.fingerprint, size: 45, color: QontaColors.accentYellow),
                                      ),
                                    ],
                                  ],
                                ),

                                const SizedBox(height: 15),

                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RegisterScreen())),
                                      child: const Text("Registrarme", style: TextStyle(color: QontaColors.primaryBlue, fontWeight: FontWeight.bold)),
                                    ),
                                    GestureDetector(
                                      onTap: () {},
                                      child: const Text("¿Olvidaste tu clave?", style: TextStyle(color: QontaColors.primaryBlue)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon({
    IconData? iconData, // Opción A: Icono estándar de Flutter
    String? svgPath,    // Opción B: Ruta de archivo SVG
    required String label,
    bool isActive = false,
  }) {
    const activeColor = QontaColors.accentYellow;
    const inactiveColor = Colors.white;
    final currentColor = isActive ? activeColor : inactiveColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isActive)
              SvgPicture.asset(
                'assets/icons/active_border.svg',
                height: 70,
                width: 70,
              ),

            Padding(
              padding: const EdgeInsets.all(10.0),
              child: svgPath != null
                  ? SvgPicture.asset(
                svgPath,
                height: 45,
                width: 45,
                colorFilter: ColorFilter.mode(currentColor, BlendMode.srcIn),
              )
                  : Icon(
                iconData,
                size: 45,
                color: currentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: currentColor,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
