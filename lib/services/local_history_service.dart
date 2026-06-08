import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// History sensor lokal — disimpan di HP setiap kali data WS subId=4 masuk.
/// Interval minimum 10 detik (cukup untuk testing + produksi ESP32 ~3s interval).
/// Aggregasi harian saat ditampilkan di grafik.
class LocalHistoryService {
  static const int _minIntervalMs = 10 * 1000;  // 10 detik
  static const int _maxEntries    = 50000;       // ~57 hari di interval 10s

  /// Simpan data point baru
  static Future<void> addEntry(String key, double value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('lh_$key') ?? '[]';
      final list  = (jsonDecode(raw) as List).cast<List<dynamic>>();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Skip kalau entry terakhir terlalu baru
      if (list.isNotEmpty) {
        final lastTs = list.last[0] as int;
        if (nowMs - lastTs < _minIntervalMs) return;
      }

      list.add([nowMs, value]);

      // Trim kalau terlalu banyak
      if (list.length > _maxEntries) {
        list.removeRange(0, list.length - _maxEntries);
      }

      await prefs.setString('lh_$key', jsonEncode(list));
    } catch (e) {
      print('[LocalHistory] addEntry error: $e');
    }
  }

  /// Ambil semua raw data dalam rentang waktu
  static Future<List<Map<String, dynamic>>> getHistoryRange(
      String key, DateTime start, DateTime end) async {
    try {
      final prefs   = await SharedPreferences.getInstance();
      final raw     = prefs.getString('lh_$key') ?? '[]';
      final list    = (jsonDecode(raw) as List).cast<List<dynamic>>();
      final startMs = start.millisecondsSinceEpoch;
      final endMs   = end.millisecondsSinceEpoch;

      return list
          .where((e) => e[0] as int >= startMs && e[0] as int <= endMs)
          .map((e) => {
                'ts'   : e[0] as int,
                'value': (e[1] as num).toDouble(),
              })
          .toList();
    } catch (e) {
      print('[LocalHistory] getHistoryRange error: $e');
      return [];
    }
  }

  /// Ambil rata-rata harian dalam rentang waktu (untuk grafik 30 hari)
  static Future<List<Map<String, dynamic>>> getDailyAverages(
      String key, DateTime start, DateTime end) async {
    final raw = await getHistoryRange(key, start, end);
    if (raw.isEmpty) return [];

    // Kelompokkan berdasarkan tanggal
    final Map<String, List<double>> byDay = {};
    final Map<String, int> dayTs = {};

    for (final entry in raw) {
      final ts    = entry['ts'] as int;
      final val   = entry['value'] as double;
      final date  = DateTime.fromMillisecondsSinceEpoch(ts);
      final dayKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      byDay.putIfAbsent(dayKey, () => []);
      byDay[dayKey]!.add(val);

      // Simpan timestamp awal hari
      if (!dayTs.containsKey(dayKey)) {
        final dayStart = DateTime(date.year, date.month, date.day);
        dayTs[dayKey] = dayStart.millisecondsSinceEpoch;
      }
    }

    // Hitung rata-rata per hari
    final result = byDay.entries.map((e) {
      final avg = e.value.reduce((a, b) => a + b) / e.value.length;
      return {'ts': dayTs[e.key]!, 'value': avg};
    }).toList();

    // Sort by timestamp
    result.sort((a, b) => (a['ts'] as int).compareTo(b['ts'] as int));

    return result;
  }

  /// Statistik jumlah data tersimpan
  static Future<Map<String, int>> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = <String, int>{};
    for (final key in ['ph', 'tds', 'temperature']) {
      final raw  = prefs.getString('lh_$key') ?? '[]';
      final list = jsonDecode(raw) as List;
      stats[key] = list.length;
    }
    return stats;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['ph', 'tds', 'temperature']) {
      await prefs.remove('lh_$key');
    }
  }
}
