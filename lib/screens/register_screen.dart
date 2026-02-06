import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart'; // Para colores y Dashboard

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final String ipAddress = "192.168.0.4";

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
        // Registro exitoso, vamos al Dashboard
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

          // 2. CONTENIDO
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // --- ICONOS DECORATIVOS SUPERIORES ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Icono Personas
                              const Icon(Icons.groups, color: Colors.white, size: 50),
                              
                              // Icono Gráfico (LEVANTADO CON PADDING PARA QUE ESTÉ MÁS ALTO)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 40), // <--- ESTO LO SUBE
                                child: Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    const Icon(Icons.bar_chart, color: Colors.white, size: 70),
                                    Transform.translate(
                                      offset: const Offset(10, -10),
                                      child: const Icon(Icons.trending_up, color: QontaColors.accentYellow, size: 50)
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(Icons.menu_book, color: Colors.white, size: 50),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        SizedBox(
                          height: 120, // <--- AUMENTADO DE 60 A 120
                          child: Image.asset('assets/logo.png', fit: BoxFit.contain, 
                            errorBuilder: (c,o,s) => const Text("Qonta", style: TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold))), 
                        ),
                        
                        const SizedBox(height: 10),
                        const Text(
                          "La Contabilidad\nnunca fue tan facil",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            height: 1.2
                          ),
                        ),

                        const SizedBox(height: 30),

                        // --- TARJETA DE REGISTRO ---
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 30),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Column(
                            children: [
                              _buildCustomTextField(
                                controller: _nameController, 
                                label: "Nombre Completo",
                                isObscure: false
                              ),
                              const SizedBox(height: 15),

                              _buildCustomTextField(
                                controller: _emailController, 
                                label: "Usuario (Email)",
                                isObscure: false
                              ),
                              const SizedBox(height: 15),

                              _buildCustomTextField(
                                controller: _passController, 
                                label: "Contraseña",
                                isObscure: true
                              ),
                              
                              const SizedBox(height: 25),

                              // BOTÓN CONTINUAR CON FADE (GRADIENTE)
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(25),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF1565C0), // Azul más claro
                                      Color(0xFF0D47A1), // Azul más oscuro (Efecto Fade)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _registrarse,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent, // Transparente para ver el gradiente
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  ),
                                  child: _isLoading 
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text("Continuar", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                              ),

                              const SizedBox(height: 15),

                              _buildSocialButton(
                                text: "Continuar con Facebook",
                                color: Colors.blue[800]!,
                                icon: Icons.facebook, 
                              ),

                              const SizedBox(height: 10),

                              _buildSocialButton(
                                text: "Continuar con Google",
                                color: Colors.red,
                                icon: Icons.g_mobiledata,
                                isGoogle: true
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
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

  // Widget para los inputs (MÁS PEQUEÑOS)
  Widget _buildCustomTextField({required TextEditingController controller, required String label, required bool isObscure}) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      style: const TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold),
        // REDUCIDO EL PADDING VERTICAL PARA HACERLOS MÁS PEQUEÑOS
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), 
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: QontaColors.accentYellow, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: QontaColors.accentYellow, width: 2),
          borderRadius: BorderRadius.circular(30),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required String text, required Color color, required IconData icon, bool isGoogle = false}) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: () {}, 
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: QontaColors.accentYellow, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          backgroundColor: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (isGoogle) 
               const Icon(Icons.circle, color: Colors.red, size: 24)
            else 
               Icon(icon, color: color, size: 28),
            
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                // Quitamos 'const' aquí porque 'text' es variable
                style: const TextStyle(color: QontaColors.accentYellow, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}