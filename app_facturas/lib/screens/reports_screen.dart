import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart'; // Asegúrate de agregar fl_chart al pubspec.yaml
import 'package:intl/intl.dart'; // Para formateo de moneda
import '../main.dart'; // Para QontaColors

class ReportsScreen extends StatefulWidget {
  final int userId;
  final String ipAddress;

  const ReportsScreen({super.key, required this.userId, required this.ipAddress});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final double _ventasNetas = 15000.00;
  final double _costoVentas = 6500.00;
  final double _gastosOperativos = 3200.00;
  final double _impuestos = 1590.00; // Ejemplo ~30% de operativa

  // Cálculos derivados (Estado de Resultados)
  double get _utilidadBruta => _ventasNetas - _costoVentas;
  double get _utilidadOperativa => _utilidadBruta - _gastosOperativos;
  double get _utilidadNeta => _utilidadOperativa - _impuestos;

  String _periodoSeleccionado = "Octubre 2023"; // Esto sería un filtro real
  int _chartTouchedIndex = -1; // Para interacción con el gráfico

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ', decimalDigits: 2);
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Informes Financieros", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: QontaColors.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              // Lógica futura para descargar PDF/Excel
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Descargar reporte (Próximamente)")));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER / FILTRO DE FECHA
            _buildHeaderFilter(),

            // 2. TARJETAS DE RESUMEN CLAVE
            _buildSummaryCards(),

            const SizedBox(height: 20),

            // 3. SECCIÓN GRÁFICA (Distribución)
            _buildChartSection(),

            const SizedBox(height: 20),

            // 4. ESTADO DE RESULTADOS DETALLADO (Data obligatoria de la imagen)
            _buildDetailedStatement(),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- WIDGETS DE SECCIÓN ---

  Widget _buildHeaderFilter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: QontaColors.primaryBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Periodo del reporte", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 5),
              Row(
                children: [
                  Text(_periodoSeleccionado, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 10),
                  const Icon(Icons.calendar_today, color: QontaColors.accentYellow, size: 18),
                ],
              ),
            ],
          ),
          // Botón simulado de filtro
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(15)),
            child: const Row(children: [Text("Mensual", style: TextStyle(color: Colors.white)), Icon(Icons.arrow_drop_down, color: Colors.white)]),
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          // Tarjeta de Ventas Totales
          Expanded(
            child: _buildHighlightCard(
              title: "Ventas Totales",
              amount: _ventasNetas,
              icon: Icons.trending_up,
              color: Colors.blue,
              bgColor: Colors.blue.shade50,
            ),
          ),
          const SizedBox(width: 15),
          // Tarjeta de Utilidad Neta
          Expanded(
            child: _buildHighlightCard(
              title: "Utilidad Neta",
              amount: _utilidadNeta,
              icon: Icons.monetization_on,
              color: _utilidadNeta >= 0 ? Colors.green : Colors.red,
              bgColor: _utilidadNeta >= 0 ? Colors.green.shade50 : Colors.red.shade50,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    // Porcentajes para el gráfico
    double total = _ventasNetas; // Asumimos ventas como el 100% base para este gráfico simplificado
    if (total == 0) total = 1;

    double pctCosto = (_costoVentas / total) * 100;
    double pctGastos = (_gastosOperativos / total) * 100;
    double pctImpuestos = (_impuestos / total) * 100;
    double pctUtilidad = (_utilidadNeta / total) * 100;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Distribución de Ingresos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: QontaColors.cardBlue)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                // GRÁFICO CIRCULAR (FL_CHART)
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions || pieTouchResponse == null || pieTouchResponse.touchedSection == null) {
                              _chartTouchedIndex = -1;
                              return;
                            }
                            _chartTouchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        _buildPieSection(0, pctCosto, Colors.orange.shade400, "Costo Ventas"),
                        _buildPieSection(1, pctGastos, Colors.orange.shade200, "Gastos Op."),
                        _buildPieSection(2, pctImpuestos, Colors.red.shade300, "Impuestos"),
                        _buildPieSection(3, pctUtilidad, Colors.green.shade400, "Utilidad Neta"),
                      ],
                    ),
                  ),
                ),
                // LEYENDA DEL GRÁFICO
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLegendItem(Colors.orange.shade400, "Costo Ventas"),
                      _buildLegendItem(Colors.orange.shade200, "Gastos Op."),
                      _buildLegendItem(Colors.red.shade300, "Impuestos"),
                      _buildLegendItem(Colors.green.shade400, "Utilidad Neta"),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedStatement() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text("Estado de Resultados", style: TextStyle(color: QontaColors.cardBlue, fontSize: 20, fontWeight: FontWeight.bold)),
              Icon(Icons.receipt_long_rounded, color: QontaColors.accentYellow),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 15),

          // --- ESTRUCTURA JERÁRQUICA DE LA IMAGEN ---
          _buildReportRow("Ventas Netas", _ventasNetas, isBold: true, fontSize: 16),
          _buildReportRow("Costo de Ventas", -_costoVentas, indent: 1, textColor: Colors.red.shade700),

          const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Divider(indent: 20)),
          _buildReportRow("Utilidad Bruta", _utilidadBruta, isBold: true, isTotalLabel: true),

          const SizedBox(height: 15),
          _buildReportRow("Gastos Operativos", -_gastosOperativos, indent: 1, textColor: Colors.red.shade700),

          const Padding(padding: EdgeInsets.symmetric(vertical: 5), child: Divider(indent: 20)),
          _buildReportRow("Utilidad Operativa", _utilidadOperativa, isBold: true, isTotalLabel: true),

          const SizedBox(height: 15),
          _buildReportRow("Impuestos", -_impuestos, indent: 1, textColor: Colors.red.shade700),

          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
                color: _utilidadNeta >= 0 ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _utilidadNeta >= 0 ? Colors.green.shade200 : Colors.red.shade200)
            ),
            child: _buildReportRow(
                "Utilidad Neta",
                _utilidadNeta,
                isBold: true,
                fontSize: 18,
                textColor: _utilidadNeta >= 0 ? Colors.green.shade800 : Colors.red.shade800
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES PEQUEÑOS ---

  Widget _buildHighlightCard({required String title, required double amount, required IconData icon, required Color color, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 15),
          Text(title, style: TextStyle(color: color.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_formatCurrency(amount), style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(String label, double value, {bool isBold = false, double indent = 0, Color? textColor, double fontSize = 15, bool isTotalLabel = false}) {
    TextStyle textStyle = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: fontSize,
      color: textColor ?? (isTotalLabel ? QontaColors.cardBlue : Colors.grey.shade800),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: EdgeInsets.only(left: indent * 20.0),
            child: Text(label, style: textStyle),
          ),
          Text(
            // Si es negativo visualmente (costos/gastos), lo mostramos entre paréntesis o con menos según prefieras.
            // Aquí uso el valor directo que ya viene negativo en el DataRow.
              _formatCurrency(value),
              style: textStyle
          ),
        ],
      ),
    );
  }

  // Helpers para el Gráfico
  PieChartSectionData _buildPieSection(int index, double percentage, Color color, String title) {
    final isTouched = index == _chartTouchedIndex;
    final fontSize = isTouched ? 18.0 : 14.0;
    final radius = isTouched ? 60.0 : 50.0;

    return PieChartSectionData(
      color: color,
      value: percentage,
      title: '${percentage.toStringAsFixed(0)}%',
      radius: radius,
      titleStyle: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.white),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}