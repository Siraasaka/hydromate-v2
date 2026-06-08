import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/tb_service.dart';

class PpmHistoryScreen extends StatefulWidget {
  const PpmHistoryScreen({super.key});
  @override
  State<PpmHistoryScreen> createState() => _PpmHistoryScreenState();
}

class _PpmHistoryScreenState extends State<PpmHistoryScreen> {
  static const Color kTeal    = Color(0xFF3299A0);
  static const Color kDark    = Color(0xFF2D5072);
  static const Color kWarning = Color(0xFFFFB74D);

  List<FlSpot> _spots = [];
  List<Map<String, dynamic>> _tableData = [];
  bool _loading = true;
  double _tdsMin = 800, _tdsMax = 1200;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final attrs = await TbService.instance.getSharedAttributes();
    _tdsMin = double.tryParse(attrs['tds_min']?.toString() ?? '') ?? 800;
    _tdsMax = double.tryParse(attrs['tds_max']?.toString() ?? '') ?? 1200;

    final end   = DateTime.now();
    final start = end.subtract(const Duration(days: 30));
    final data  = await TbService.instance.getTelemetryHistory(
      key: 'tds', start: start, end: end,
      agg: 'AVG', intervalMs: 86400000,
    );

    final spots = <FlSpot>[];
    final table = <Map<String, dynamic>>[];
    for (int i = 0; i < data.length; i++) {
      final ts   = data[i]['ts'] as int;
      final val  = data[i]['value'] as double;
      final date = DateTime.fromMillisecondsSinceEpoch(ts);
      final warn = val < _tdsMin || val > _tdsMax;
      spots.add(FlSpot(i.toDouble(), val));
      table.add({
        'tanggal': DateFormat('dd MMM yy').format(date),
        'ppm'    : val.round().toString(),
        'status' : warn ? 'Warning' : 'Normal',
        'color'  : warn ? kWarning : kTeal,
      });
    }
    if (mounted) setState(() { _spots = spots; _tableData = table; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: kTeal, size: 35),
          onPressed: () => Navigator.of(context).pop()),
        title: const Text('RIWAYAT PPM',
            style: TextStyle(color: kTeal, fontWeight: FontWeight.bold,
                fontSize: 22, letterSpacing: 4.0)),
        centerTitle: true,
        actions: [IconButton(icon: const Icon(Icons.refresh, color: kTeal), onPressed: _loadData)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _tableData.isEmpty
              ? const Center(child: Text('Belum ada data history', style: TextStyle(color: Colors.grey)))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: kTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.info_outline, size: 14, color: kTeal),
            const SizedBox(width: 6),
            Text('Target PPM: ${_tdsMin.round()} – ${_tdsMax.round()}',
                style: const TextStyle(color: kTeal, fontWeight: FontWeight.bold, fontSize: 13)),
          ]),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Grafik TDS/PPM (30 Hari)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: kDark, fontSize: 16)),
              const SizedBox(height: 12),
              SizedBox(height: 200, child: LineChart(_buildChart())),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              const Text('Data Harian',
                  style: TextStyle(fontWeight: FontWeight.bold, color: kDark, fontSize: 16)),
              const SizedBox(height: 8),
              Table(
                border: TableBorder.all(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.5)},
                children: [
                  _headerRow(['Tanggal', 'PPM', 'Status']),
                  ..._tableData.reversed.take(15).map(_dataRow),
                ],
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  LineChartData _buildChart() {
    final minY = (_tdsMin * 0.7).clamp(0.0, double.infinity);
    final maxY = _tdsMax * 1.3;
    return LineChartData(
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
      titlesData: FlTitlesData(
        bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40,
            getTitlesWidget: (v, _) => Text(v.round().toString(),
                style: const TextStyle(fontSize: 10, color: kDark)))),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      minY: minY.toDouble(), maxY: maxY.toDouble(),
      extraLinesData: ExtraLinesData(horizontalLines: [
        HorizontalLine(y: _tdsMin, color: kWarning.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [4,4]),
        HorizontalLine(y: _tdsMax, color: kWarning.withValues(alpha: 0.6), strokeWidth: 1, dashArray: [4,4]),
      ]),
      lineBarsData: [LineChartBarData(
        spots: _spots, isCurved: true, color: kTeal, barWidth: 2.5,
        dotData: FlDotData(show: _spots.length < 15),
        belowBarData: BarAreaData(show: true, color: kTeal.withValues(alpha: 0.08)),
      )],
    );
  }

  TableRow _headerRow(List<String> titles) => TableRow(
    decoration: BoxDecoration(color: kTeal.withValues(alpha: 0.1)),
    children: titles.map((t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold,
          color: kDark, fontSize: 12), textAlign: TextAlign.center),
    )).toList(),
  );

  TableRow _dataRow(Map<String, dynamic> d) => TableRow(children: [
    Padding(padding: const EdgeInsets.all(6),
        child: Text(d['tanggal'], style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
    Padding(padding: const EdgeInsets.all(6),
        child: Text(d['ppm'], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center)),
    Padding(padding: const EdgeInsets.all(6),
        child: Text(d['status'],
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: d['color']),
            textAlign: TextAlign.center)),
  ]);
}
