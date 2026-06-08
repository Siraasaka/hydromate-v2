import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/tb_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  static const Color kTeal     = Color(0xFF3299A0);
  static const Color kWarning  = Color(0xFFFFB74D);
  static const Color kCritical = Color(0xFFE57373);
  static const Color kNormal   = Color(0xFF81C784);

  List<Map<String, dynamic>> _alarms = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() => _loading = true);
    final alarms = await TbService.instance.getAlarms(pageSize: 50);
    if (mounted) setState(() { _alarms = alarms; _loading = false; });
  }

  String _formatTs(int? ts) {
    if (ts == null) return '--';
    return DateFormat('dd MMM yyyy, HH:mm').format(
        DateTime.fromMillisecondsSinceEpoch(ts));
  }

  Color _severityColor(String? severity) {
    switch (severity?.toUpperCase()) {
      case 'CRITICAL': return kCritical;
      case 'MAJOR':    return Colors.orange;
      case 'WARNING':  return kWarning;
      default:         return Colors.grey;
    }
  }

  IconData _alarmIcon(String? type) {
    final t = type?.toLowerCase() ?? '';
    if (t.contains('ph'))     return Icons.science_outlined;
    if (t.contains('tds'))    return Icons.water_drop_outlined;
    if (t.contains('offline') || t.contains('device')) return Icons.wifi_off;
    return Icons.warning_amber_rounded;
  }

  String _statusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE_UNACK': return 'Aktif';
      case 'ACTIVE_ACK':   return 'Aktif (Diakui)';
      case 'CLEARED_UNACK':return 'Selesai';
      case 'CLEARED_ACK':  return 'Selesai (Diakui)';
      default: return status ?? '--';
    }
  }

  bool _isActive(String? status) =>
      status?.toUpperCase().startsWith('ACTIVE') ?? false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.chevron_left, color: kTeal, size: 35),
                onPressed: () => Navigator.of(context).pop())
            : null,
        title: const Text('NOTIFIKASI',
            style: TextStyle(color: kTeal, fontWeight: FontWeight.bold,
                fontSize: 22, letterSpacing: 4.0)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: kTeal),
            onPressed: _loadAlarms,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kTeal))
          : _alarms.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadAlarms,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alarms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _buildAlarmCard(_alarms[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.check_circle_outline, size: 64, color: kNormal),
      const SizedBox(height: 16),
      const Text('Tidak ada alarm', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF2D5072))),
      const SizedBox(height: 8),
      const Text('Semua parameter dalam batas normal', style: TextStyle(color: Colors.grey)),
    ]));
  }

  Widget _buildAlarmCard(Map<String, dynamic> alarm) {
    final type     = alarm['type']?.toString() ?? 'Alert';
    final severity = alarm['severity']?.toString();
    final status   = alarm['status']?.toString();
    final createdTs = alarm['createdTime'] as int?;
    final active   = _isActive(status);
    final color    = _severityColor(severity);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.1),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle),
          child: Icon(_alarmIcon(type), color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(type,
                style: const TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 15, color: Color(0xFF2D5072)))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: active ? color : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8)),
              child: Text(_statusLabel(status),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                      color: active ? Colors.white : Colors.grey.shade600)),
            ),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
              child: Text(severity ?? 'Unknown',
                  style: TextStyle(fontSize: 11, color: color,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(_formatTs(createdTs),
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ])),
      ]),
    );
  }
}
