import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../main.dart';

class EditarDatosScreen extends StatefulWidget {
  final Map<String, dynamic> datos;
  final bool esVenta;
  final String ipAddress;
  final int userId;

  const EditarDatosScreen({
    super.key,
    required this.datos,
    required this.esVenta,
    required this.ipAddress,
    required this.userId
  });

  @override
  State<EditarDatosScreen> createState() => _EditarDatosScreenState();
}

class _EditarDatosScreenState extends State<EditarDatosScreen> {
  bool _isSaving = false;

  String _selectedDocType = "Factura";

  late TextEditingController _rucEmisorController;
  late TextEditingController _nombreEmisorController;
  late TextEditingController _dirEmisorController;
  late TextEditingController _telEmisorController;

  late TextEditingController _rucClienteController;
  late TextEditingController _nombreClienteController;

  late TextEditingController _montoController;
  late TextEditingController _fechaController;
  late TextEditingController _codigoController;

  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();

    String tipoDetectado = widget.datos['tipo_comprobante'] ?? "Factura";
    if (tipoDetectado.toLowerCase().contains("boleta")) {
      _selectedDocType = "Boleta";
    } else {
      _selectedDocType = "Factura";
    }

    if (widget.datos['items'] != null) {
      _items = List.from(widget.datos['items']);
    }

    _rucEmisorController = TextEditingController(text: widget.esVenta
        ? ""
        : (widget.datos['proveedor_ruc']?.toString() ?? ""));

    _nombreEmisorController = TextEditingController(text: widget.esVenta
        ? ""
        : (widget.datos['proveedor_razon_social'] ?? ""));

    _dirEmisorController = TextEditingController(text: widget.esVenta
        ? ""
        : (widget.datos['proveedor_direccion'] ?? ""));

    _telEmisorController = TextEditingController(text: widget.esVenta
        ? ""
        : (widget.datos['proveedor_telefono'] ?? ""));

    _rucClienteController = TextEditingController(text: widget.esVenta
        ? (widget.datos['cliente_nro_doc']?.toString() ?? "")
        : "");

    _nombreClienteController = TextEditingController(text: widget.esVenta
        ? (widget.datos['cliente_razon_social'] ?? "")
        : "");

    var monto = widget.datos['monto_total'] ?? widget.datos['total_cp'];
    _montoController = TextEditingController(text: monto?.toString() ?? "0.0");

    _fechaController = TextEditingController(text: widget.datos['fecha_emision'] ?? "");
    _codigoController = TextEditingController(text: "${widget.datos['serie'] ?? ''}-${widget.datos['numero'] ?? ''}");
  }

  @override
  void dispose() {
    _rucEmisorController.dispose();
    _nombreEmisorController.dispose();
    _dirEmisorController.dispose();
    _telEmisorController.dispose();
    _rucClienteController.dispose();
    _nombreClienteController.dispose();
    _montoController.dispose();
    _fechaController.dispose();
    _codigoController.dispose();
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
        "serie": _codigoController.text,
        "tipo_comprobante": _selectedDocType,

        if (widget.esVenta) ...{
          "cliente_nro_doc": _rucClienteController.text,
          "cliente_razon_social": _nombreClienteController.text,
        } else ...{
          "proveedor_ruc": _rucEmisorController.text,
          "proveedor_razon_social": _nombreEmisorController.text,
          "proveedor_direccion": _dirEmisorController.text,
          "proveedor_telefono": _telEmisorController.text
        },

        "items": _items
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
        Navigator.pop(context);
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
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Datos extraídos del\nticket",
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.1),
                ),
                const SizedBox(height: 15),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _confirmarYGuardar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: QontaColors.accentYellow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      elevation: 4,
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Confirmar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black],
                      stops: [0.0, 0.08], // El fade ocupa el 8% superior
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTopControlBar(),

                        const SizedBox(height: 25),
                        _buildSectionTitle("Datos del emisor"),
                        const SizedBox(height: 10),
                        _buildStyledTextField("RUC:", _rucEmisorController),
                        _buildStyledTextField("Razón social:", _nombreEmisorController),
                        _buildStyledTextField("Dirección Fiscal:", _dirEmisorController),
                        _buildStyledTextField("Teléfono o correo:", _telEmisorController),

                        const SizedBox(height: 25),
                        _buildSectionTitle("Datos del Cliente"),
                        const SizedBox(height: 10),
                        _buildStyledTextField("RUC:", _rucClienteController),
                        _buildStyledTextField("Razón social:", _nombreClienteController),

                        const SizedBox(height: 25),
                        _buildSectionTitle("Elementos"),
                        const SizedBox(height: 10),
                        _buildItemsTable(),

                        const SizedBox(height: 10),

                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTopControlBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    "Categoría",
                    style: TextStyle(color: QontaColors.cardBlue, fontWeight: FontWeight.bold, fontSize: 16)
                ),
                const SizedBox(height: 5),
                DropdownButton<String>(
                  value: _selectedDocType,
                  underline: Container(),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                  items: <String>['Factura', 'Boleta'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, color: QontaColors.primaryBlue, size: 20),
                          const SizedBox(width: 5),
                          Text(value, style: const TextStyle(color: Colors.blue, fontSize: 16)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedDocType = newValue!;
                    });
                  },
                ),
              ],
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                    "Fecha",
                    style: TextStyle(color: QontaColors.cardBlue, fontWeight: FontWeight.bold, fontSize: 16)
                ),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    border: Border.all(color: QontaColors.accentYellow),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _fechaController.text.isNotEmpty ? _fechaController.text : "00/00/0000",
                    style: const TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold),
                  ),
                )
              ],
            )
          ],
        ),

        const SizedBox(height: 15),

        Row(
          children: [
            const Text("Codigo", style: TextStyle(color: Colors.blue, fontSize: 14)),
            const SizedBox(width: 15),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(
                border: Border.all(color: QontaColors.accentYellow),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _codigoController.text.isNotEmpty ? _codigoController.text : "---",
                style: const TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold),
              ),
            )
          ],
        )
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: QontaColors.cardBlue, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildStyledTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, bottom: 2),
            child: Text(label, style: const TextStyle(color: Colors.blue, fontSize: 13)),
          ),
          SizedBox(
            height: 45,
            child: TextField(
              controller: controller,
              style: const TextStyle(color: QontaColors.accentYellow, fontWeight: FontWeight.bold, fontSize: 14),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: QontaColors.accentYellow, width: 1.5),
                  borderRadius: BorderRadius.circular(25),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: QontaColors.primaryBlue, width: 2),
                  borderRadius: BorderRadius.circular(25),
                ),
                fillColor: Colors.white,
                filled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTable() {
    double total = double.tryParse(_montoController.text) ?? 0.0;
    double subtotal = total / 1.18;
    double igv = total - subtotal;

    return Column(
      children: [
        Container(
          height: 50,
          decoration: const BoxDecoration(
            color: QontaColors.accentYellow,
            borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(
            children: [
              _buildHeaderCell("Item", flex: 2),
              _buildHeaderDivider(),
              _buildHeaderCell("Descripción", flex: 6, align: TextAlign.left),
              _buildHeaderDivider(),
              _buildHeaderCell("Cantidad", flex: 3),
              _buildHeaderDivider(),
              _buildHeaderCell("Precio\nUnitario", flex: 3),
              _buildHeaderDivider(),
              _buildHeaderCell("Sub\nTotal", flex: 3),
            ],
          ),
        ),

        if (_items.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: QontaColors.primaryBlue)),
            ),
            child: const Center(
                child: Text("No se detectaron items", style: TextStyle(color: Colors.grey))
            ),
          )
        else
          ..._items.asMap().entries.map((entry) {
            int index = entry.key + 1;
            var item = entry.value;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 5),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: QontaColors.primaryBlue, width: 1.5)),
              ),
              child: Row(
                children: [
                  _buildDataCell(index.toString(), flex: 2),
                  _buildDataCell(item['descripcion'] ?? "-", flex: 6, align: TextAlign.left),
                  _buildDataCell(item['cantidad'].toString(), flex: 3),
                  _buildDataCell((item['precio_unitario'] ?? 0).toString(), flex: 3),
                  _buildDataCell((item['total'] ?? 0).toString(), flex: 3),
                ],
              ),
            );
          }).toList(),

        const SizedBox(height: 15),

        Align(
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTotalRow("Gravada", "S/ ${subtotal.toStringAsFixed(2)}"),
              _buildTotalRow("IGV 18.00%", "S/ ${igv.toStringAsFixed(2)}"),
              _buildTotalRow("Total", "S/ ${total.toStringAsFixed(2)}", isTotal: true),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Center(
          child: Icon(Icons.qr_code_2, size: 60, color: Colors.blue.shade700),
        ),
      ],
    );
  }


  Widget _buildHeaderCell(String text, {required int flex, TextAlign align = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildHeaderDivider() {
    return Container(
      width: 1.5,
      height: 30,
      color: Colors.white,
    );
  }

  Widget _buildDataCell(String text, {required int flex, TextAlign align = TextAlign.center}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 12,
              fontWeight: FontWeight.w500
          ),
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              label,
              style: TextStyle(
                  color: isTotal ? QontaColors.accentYellow : const Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                  fontSize: 14
              )
          ),
          const SizedBox(width: 20),
          SizedBox(
            width: 80,
            child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                    color: const Color(0xFF1565C0),
                    fontWeight: FontWeight.bold,
                    fontSize: isTotal ? 16 : 14
                )
            ),
          ),
        ],
      ),
    );
  }
}