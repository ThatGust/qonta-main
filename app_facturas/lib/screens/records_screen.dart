import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';
import 'edit_record_screen.dart';

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
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _eliminarRegistro(int id) async {
    try {
      var uri = Uri.parse("http://${widget.ipAddress}:8000/eliminar-registro/$_filtroTipo/$id");
      var response = await http.delete(uri);

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Registro eliminado correctamente"), backgroundColor: Colors.green)
        );
        // No necesitamos recargar todo, el Dismissible ya lo quitó visualmente,
        // pero actualizamos la lista interna para evitar errores.
        setState(() {
          _registros.removeWhere((item) => item['id'] == id);
        });
      } else {
        _cargarRegistros(); // Si falla, recargamos para que vuelva a aparecer
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error al eliminar el registro"), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      _cargarRegistros();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error de conexión: $e"), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _editarRegistro(int id, bool esGasto) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var uri = Uri.parse("http://${widget.ipAddress}:8000/obtener-detalle/$_filtroTipo/$id");
      var response = await http.get(uri);

      Navigator.pop(context);

      if (response.statusCode == 200) {
        var datosCompletos = json.decode(response.body);

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditarDatosScreen(
              datos: datosCompletos,
              esVenta: !esGasto,
              ipAddress: widget.ipAddress,
              userId: widget.userId,
            ),
          ),
        );
        _cargarRegistros();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al cargar detalles")));
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Mis Registros", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: QontaColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15.0),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFilterChip("Gastos", "compras", Colors.orange),
                const SizedBox(width: 15),
                _buildFilterChip("Ingresos", "ventas", Colors.blue),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _registros.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.description_outlined, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 10),
                const Text("No hay registros en esta categoría", style: TextStyle(color: Colors.grey)),
              ],
            )
                : ListView.builder(
              padding: const EdgeInsets.all(15),
              physics: const BouncingScrollPhysics(),
              itemCount: _registros.length,
              itemBuilder: (context, index) {
                final item = _registros[index];
                bool esGasto = _filtroTipo == "compras";
                Key itemKey = Key(item['id'].toString());

                // --- DISMISSIBLE PARA DESLIZAR ---
                return Dismissible(
                  key: itemKey,
                  direction: DismissDirection.endToStart, // Deslizar de derecha a izquierda
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete_outline, color: Colors.white, size: 32),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext ctx) {
                        return AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          title: const Text("Eliminar Registro"),
                          content: const Text("¿Estás seguro de que deseas eliminar este registro permanentemente?"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(false),
                              child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(true),
                              child: const Text("Eliminar", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    _eliminarRegistro(item['id']);
                  },
                  child: Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: ListTile(
                      onTap: () => _editarRegistro(item['id'], esGasto),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      leading: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(
                          color: esGasto ? Colors.orange.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          esGasto ? Icons.arrow_downward : Icons.arrow_upward,
                          color: esGasto ? Colors.orange : Colors.blue,
                        ),
                      ),
                      title: Text(
                          item['titulo'] ?? "Sin título",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 5),
                          Text(item['fecha'] ?? "--/--/----", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          if (item['categoria'] != null)
                            Text(item['categoria'], style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                      trailing: Text(
                          "S/ ${item['monto']}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: esGasto ? Colors.red[700] : Colors.green[700]
                          )
                      ),
                    ),
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
    return GestureDetector(
      onTap: () {
        if (!selected) {
          setState(() {
            _filtroTipo = valor;
            _cargarRegistros();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.grey.shade300),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}