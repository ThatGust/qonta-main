import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../main.dart'; // Para QontaColors

class CompanyScreen extends StatefulWidget {
  final int userId;
  final String ipAddress;
  final String currentRuc;
  final String currentRazon;
  final String currentDireccion;
  final String? currentLogo;

  const CompanyScreen({
    super.key,
    required this.userId,
    required this.ipAddress,
    required this.currentRuc,
    required this.currentRazon,
    required this.currentDireccion,
    this.currentLogo,
  });

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  late TextEditingController _rucController;
  late TextEditingController _razonController;
  late TextEditingController _dirController;
  bool _isSaving = false;
  bool _isUploading = false;
  String? _logoPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _rucController = TextEditingController(text: widget.currentRuc);
    _razonController = TextEditingController(text: widget.currentRazon);
    _dirController = TextEditingController(text: widget.currentDireccion);
    _logoPath = widget.currentLogo;
  }

  Future<void> _subirLogo() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isUploading = true);
    try {
      var request = http.MultipartRequest('POST', Uri.parse("http://${widget.ipAddress}:8000/subir-logo-empresa/"));
      request.fields['user_id'] = widget.userId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', image.path));
      var res = await http.Response.fromStream(await request.send());

      if (res.statusCode == 200) {
        var data = json.decode(res.body);
        setState(() => _logoPath = data['logo_path']);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _guardar() async {
    setState(() => _isSaving = true);
    try {
      var res = await http.post(
        Uri.parse("http://${widget.ipAddress}:8000/editar-empresa/"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": widget.userId,
          "ruc": _rucController.text,
          "razon_social": _razonController.text,
          "direccion": _dirController.text
        }),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, {"logo": _logoPath, "razon": _razonController.text}); // Retornamos datos
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? logoUrl;
    if (_logoPath != null && _logoPath!.isNotEmpty && !_logoPath!.contains('default')) {
      logoUrl = "http://${widget.ipAddress}:8000/static/$_logoPath?v=${DateTime.now().millisecondsSinceEpoch}";
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Mi Empresa", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: QontaColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _subirLogo,
                    child: Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: QontaColors.accentYellow, width: 2),
                        image: logoUrl != null ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover) : null,
                      ),
                      child: _isUploading
                          ? const Center(child: CircularProgressIndicator())
                          : (logoUrl == null ? const Icon(Icons.add_a_photo, size: 40, color: Colors.grey) : null),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text("Toca para cambiar el logo", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                children: [
                  _buildInput("RUC", _rucController, icon: Icons.numbers),
                  const SizedBox(height: 15),
                  _buildInput("Razón Social", _razonController, icon: Icons.business),
                  const SizedBox(height: 15),
                  _buildInput("Dirección Fiscal", _dirController, icon: Icons.location_on),
                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _guardar,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: QontaColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                      ),
                      child: _isSaving
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Guardar Datos", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {IconData? icon}) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: QontaColors.primaryBlue),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          filled: true,
          fillColor: Colors.grey[50]
      ),
    );
  }
}