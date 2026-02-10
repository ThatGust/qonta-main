import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

class ProfileScreen extends StatefulWidget {
  final int userId;
  final String currentName;
  final String currentNickname;
  final String currentEmail;
  final String ipAddress;
  final String? currentAvatar;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.currentName,
    required this.currentNickname,
    required this.currentEmail,
    required this.ipAddress,
    this.currentAvatar,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nicknameController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isSaving = false;

  bool _isUploadingImage = false;
  String? _currentAvatarPath;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nicknameController = TextEditingController(text: widget.currentNickname.isNotEmpty ? widget.currentNickname : widget.currentName.split(' ').first);
    _nameController = TextEditingController(text: widget.currentName);
    _emailController = TextEditingController(
        text: (widget.currentEmail.isNotEmpty) ? widget.currentEmail : "Cargando correo..."
    );
    _currentAvatarPath = widget.currentAvatar;
  }

  Future<void> _pickAndUploadImage() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;
    final XFile? pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile == null) return;

    setState(() => _isUploadingImage = true);

    try {
      var uri = Uri.parse("http://${widget.ipAddress}:8000/subir-avatar/");
      var request = http.MultipartRequest('POST', uri);
      request.fields['user_id'] = widget.userId.toString();
      request.files.add(await http.MultipartFile.fromPath('file', pickedFile.path));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          _currentAvatarPath = data['avatar_path'];
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Foto actualizada!"), backgroundColor: Colors.green));
      } else {
        throw Exception("Error servidor: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al subir: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _guardarCambios() async {
    setState(() => _isSaving = true);
    try {
      final uri = Uri.parse("http://${widget.ipAddress}:8000/editar-perfil/");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "user_id": widget.userId,
          "nombre_completo": _nameController.text,
          "nickname": _nicknameController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, {
          "nombre": _nameController.text,
          "nickname": _nicknameController.text,
          "avatar": _currentAvatarPath
        });
      } else {
        throw Exception("Error al guardar: ${response.statusCode}");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildCustomAppBar(context),
              _buildAvatarSection(),
              const SizedBox(height: 15),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF5F7FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(25, 25, 25, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle("DATOS PERSONALES"),
                        _buildProfileItem(Icons.star_border, "Apodo / Nickname", _nicknameController),
                        _buildProfileItem(Icons.person_outline, "Nombre Completo", _nameController),
                        _buildProfileItem(Icons.email_outlined, "Correo", _emailController, isEditable: false),
                        const SizedBox(height: 15),

                        _buildSectionTitle("OTROS DATOS"),
                        _buildProfileItem(Icons.business_center_outlined, "Tipo de Plan", TextEditingController(text: "Basic"), isEditable: false),
                        _buildProfileItem(Icons.security_outlined, "Cambiar Contraseña", null, isAction: true),

                        const Spacer(),

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _guardarCambios,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: QontaColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              elevation: 5,
                            ),
                            child: _isSaving
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Text("Guardar Cambios", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
      ),
    );
  }

  Widget _buildCustomAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(
            child: Text("Editar Perfil", textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    String? fullAvatarUrl;

    bool hasValidAvatar = _currentAvatarPath != null &&
        _currentAvatarPath!.isNotEmpty &&
        !_currentAvatarPath!.contains('default_avatar');

    if (hasValidAvatar) {
      fullAvatarUrl = "http://${widget.ipAddress}:8000/static/$_currentAvatarPath?v=${DateTime.now().millisecondsSinceEpoch}";
    }

    return GestureDetector(
      onTap: _isUploadingImage ? null : _pickAndUploadImage,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: QontaColors.accentYellow),
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: fullAvatarUrl != null
                      ? NetworkImage(fullAvatarUrl) as ImageProvider
                      : const AssetImage('assets/avatar_default.png'),
                  child: _isUploadingImage
                      ? const CircularProgressIndicator(color: QontaColors.primaryBlue)
                      : null,
                ),

              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(color: QontaColors.accentYellow, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)]),
                child: Icon(_isUploadingImage ? Icons.cloud_upload : Icons.camera_alt, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isUploadingImage ? "Subiendo imagen..." : "Toca para cambiar foto",
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5, bottom: 8),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
    );
  }

  Widget _buildProfileItem(IconData icon, String label, TextEditingController? controller, {bool isEditable = true, bool isAction = false}) {    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          const SizedBox(width: 15),
          Icon(icon, color: QontaColors.primaryBlue, size: 22),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                if (isAction)
                  const Text("Configurar", style: TextStyle(color: QontaColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14))
                else
                  SizedBox(
                    height: 25,
                    child: TextField(
                      controller: controller,
                      readOnly: !isEditable,
                      enabled: true,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: isEditable ? Colors.black87 : Colors.black54
                      ),
                      decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                    ),
                  ),
              ],
            ),
          ),
          if (isAction) const Padding(padding: EdgeInsets.only(right: 15), child: Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)),
        ],
      ),
    );
  }
}