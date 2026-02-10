import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import '../main.dart'; // Para colores y Dashboard

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final String ipAddress = "192.168.0.2"; // Asegúrate de que esta IP sea correcta

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  bool _isLoading = false;

  Future<void> _registrarse() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa todos los campos")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      var url = Uri.parse("http://$ipAddress:8000/register/");
      var response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "nombre": _nameController.text,
          "email": _emailController.text.trim(),
          "password": _passController.text
        }),
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(
              userId: data['user_id'],
              userName: data['nombre']
          )),
              (route) => false,
        );
      } else {
        var error = json.decode(response.body)['error'];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? "Error al registrar")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: Stack(
        children: [
          // 1. FONDO DEGRADADO (Base)
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
                fit: BoxFit.cover, // Estira la imagen para cubrir todo el fondo
                errorBuilder: (c, o, s) => const SizedBox(),
              ),
            ),
          ),


          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.pop(context),
                      ),
                      // Puedes agregar un título aquí si deseas, ej: "Registro"
                    ],
                  ),
                ),

                // FORMULARIO SCROLLABLE
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Icon(Icons.groups, color: Colors.white, size: 65),

                              Padding(
                                padding: const EdgeInsets.only(bottom: 20),
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    const Icon(Icons.bar_chart, color: Colors.white, size: 100),
                                    Transform.translate(
                                      offset: const Offset(15, -15),
                                      child: const Icon(Icons.trending_up, color: QontaColors.accentYellow, size: 65),
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(Icons.menu_book, color: Colors.white, size: 65),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          height: 80,
                          child: OverflowBox(
                            minHeight: 250,
                            maxHeight: 250,
                            child: Image.asset(
                              'assets/logo.png',
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              errorBuilder: (c, o, s) => const Text(
                                  "Qonta",
                                  style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        const Text(
                          "La Contabilidad\nnunca fue tan facil",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),

                        const SizedBox(height: 25),

                        // --- TARJETA DE REGISTRO ---
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildCustomTextField(
                                controller: _nameController,
                                label: "Nombre Completo",
                                isObscure: false,
                              ),
                              const SizedBox(height: 15),

                              _buildCustomTextField(
                                controller: _emailController,
                                label: "Usuario (Email)",
                                isObscure: false,
                              ),
                              const SizedBox(height: 15),

                              _buildCustomTextField(
                                controller: _passController,
                                label: "Contraseña",
                                isObscure: true,
                              ),

                              const SizedBox(height: 25),

                              // BOTÓN CONTINUAR
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _registrarse,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1565C0),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                    elevation: 2,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : const Text("Continuar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                              ),

                              const SizedBox(height: 15),

                              // BOTÓN GOOGLE
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OutlinedButton(
                                  onPressed: () {
                                    // Lógica de Google
                                  },
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    side: const BorderSide(color: Color(0xFFFFA000), width: 2),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SvgPicture.asset('assets/icons/google.svg', height: 20),
                                      SizedBox(width: 10),
                                      Text(
                                        "Ingresar con Google",
                                        style: TextStyle(
                                          color: Color(0xFFFFA000),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomTextField({required TextEditingController controller, required String label, required bool isObscure}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: QontaColors.accentYellow, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: QontaColors.cardBlue, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }


  Widget _buildSocialButton({required String text, required Color color, required IconData icon, bool isGoogle = false}) {
    return SizedBox(
      width: double.infinity,
      height: 45, // Altura reducida ligeramente
      child: OutlinedButton(
        onPressed: () {},
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: QontaColors.accentYellow, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          backgroundColor: Colors.white,
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),
            if (isGoogle)
              const Icon(Icons.circle, color: Colors.red, size: 24) // Simula logo google
            else
              Icon(icon, color: color, size: 24),

            const SizedBox(width: 15),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center, // Centrado
                style: const TextStyle(color: QontaColors.accentYellow, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 30), // Balance visual
          ],
        ),
      ),
    );
  }
}