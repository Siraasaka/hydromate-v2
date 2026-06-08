import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_history_service.dart';

class TbService {
  static const String host     = 'thingsboard.cloud';
  static const String deviceId = '94f2bd20-625e-11f1-b1fe-512fdf4b9077';

  static final TbService instance = TbService._();
  TbService._();

  String? _jwtToken;
  WebSocketChannel? _wsChannel;

  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  final _attributeController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;
  Stream<Map<String, dynamic>> get attributeStream  => _attributeController.stream;

  // History completers: cmdId → Completer
  final _historyCompleters = <int, Completer<List<Map<String, dynamic>>>>{};
  int _historyCmdCounter = 100; // mulai dari 100 biar ga bentrok sama subId 2,3,4

  bool get isLoggedIn => _jwtToken != null;

  // ── Auth ───────────────────────────────────────────────────────
  Future<bool> login(String email, String password) async {
    try {
      final resp = await http.post(
        Uri.https(host, '/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': email, 'password': password}),
      ).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        _jwtToken = jsonDecode(resp.body)['token'];
        final p = await SharedPreferences.getInstance();
        await p.setString('tb_email', email);
        await p.setString('tb_password', password);
        print('[TB] Login OK');
        return true;
      }
    } catch (e) { print('[TB] Login error: $e'); }
    return false;
  }

  Future<bool> autoLogin() async {
    final p = await SharedPreferences.getInstance();
    final e = p.getString('tb_email'), pw = p.getString('tb_password');
    if (e != null && pw != null) return login(e, pw);
    return false;
  }

  Future<void> logout() async {
    _jwtToken = null; disconnectWebSocket();
    final p = await SharedPreferences.getInstance();
    await p.remove('tb_email'); await p.remove('tb_password');
  }

  Map<String, String> get _h => {
    'Content-Type': 'application/json',
    'X-Authorization': 'Bearer $_jwtToken',
  };

  // ── Telemetry History ─────────────────────────────────────────
  // Coba REST dulu, kalau 403 fallback ke WebSocket historyCmds
  Future<List<Map<String, dynamic>>> getTelemetryHistory({
    required String key,
    required DateTime start,
    required DateTime end,
    int limit      = 500,
    String agg     = 'AVG',
    int intervalMs = 86400000,
  }) async {
    // Coba REST dulu
    try {
      final r = await http.get(
        Uri.https(host, '/api/plugins/telemetry/DEVICE/$deviceId/values/timeseries', {
          'keys'    : key,
          'startTs' : start.millisecondsSinceEpoch.toString(),
          'endTs'   : end.millisecondsSinceEpoch.toString(),
          'limit'   : limit.toString(),
          'agg'     : agg,
          'interval': intervalMs.toString(),
          'orderBy' : 'ASC',
        }), headers: _h).timeout(const Duration(seconds: 10));

      print('[TB] History REST status: ${r.statusCode}');

      if (r.statusCode == 200) {
        final raw = jsonDecode(r.body) as Map<String, dynamic>;
        if (raw.containsKey(key) && raw[key] is List) {
          final result = (raw[key] as List).map((e) =>
            {'ts': e['ts'] as int, 'value': double.tryParse(e['value'].toString()) ?? 0.0}
          ).toList();
          print('[TB] History REST OK: ${result.length} data points');
          return result;
        }
        return [];
      }
    } catch (e) { print('[TB] History REST error: $e'); }

    // Fallback: WebSocket historyCmds
    print('[TB] History REST gagal, coba WebSocket historyCmds...');
    final wsResult = await _getHistoryViaWs(
      key: key, start: start, end: end,
      limit: limit, agg: agg, intervalMs: intervalMs,
    );
    if (wsResult.isNotEmpty) return wsResult;

    // Final fallback: local history tersimpan di HP
    print('[TB] WS gagal, baca local history...');
    final localData = await LocalHistoryService.getDailyAverages(key, start, end);
    print('[TB] Local history: ' + localData.length.toString() + ' entries');
    return localData;
  }

  // WebSocket historyCmds dengan Completer
  Future<List<Map<String, dynamic>>> _getHistoryViaWs({
    required String key,
    required DateTime start,
    required DateTime end,
    int limit = 500, String agg = 'AVG', int intervalMs = 86400000,
  }) async {
    if (_wsChannel == null) return [];

    final cmdId = _historyCmdCounter++;
    final completer = Completer<List<Map<String, dynamic>>>();
    _historyCompleters[cmdId] = completer;

    try {
      _wsChannel!.sink.add(jsonEncode({
        'tsSubCmds': [],
        'historyCmds': [{
          'entityType': 'DEVICE',
          'entityId'  : deviceId,
          'keys'      : key,
          'startTs'   : start.millisecondsSinceEpoch,
          'endTs'     : end.millisecondsSinceEpoch,
          'limit'     : limit,
          'agg'       : agg,
          'interval'  : intervalMs,
          'cmdId'     : cmdId,
        }],
        'attrSubCmds': [],
      }));

      // Timeout 10 detik
      return await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _historyCompleters.remove(cmdId);
          print('[TB] historyCmds timeout untuk cmdId=$cmdId');
          return [];
        },
      );
    } catch (e) {
      _historyCompleters.remove(cmdId);
      print('[TB] historyCmds error: $e');
      return [];
    }
  }

  // ── Shared Attributes ─────────────────────────────────────────
  Future<Map<String, dynamic>> getSharedAttributes() async {
    try {
      const keys = 'ph_min,ph_max,tds_min,tds_max,preset_name,'
                   'ph_neutral_voltage,ph_acid_voltage,k_value';
      final r = await http.get(
        Uri.https(host, '/api/plugins/telemetry/DEVICE/$deviceId/values/attributes/SHARED_SCOPE',
          {'keys': keys}), headers: _h).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        return {for (var e in list) e['key']: e['value']};
      }
    } catch (e) { print('[TB] getSharedAttributes error: $e'); }
    return {};
  }

  Future<bool> saveSharedAttributes(Map<String, dynamic> attrs) async {
    try {
      final r = await http.post(
        Uri.https(host, '/api/plugins/telemetry/$deviceId/SHARED_SCOPE'),
        headers: _h, body: jsonEncode(attrs)).timeout(const Duration(seconds: 10));
      print('[TB] saveSharedAttributes → ${r.statusCode}');
      return r.statusCode == 200;
    } catch (e) { print('[TB] saveSharedAttributes error: $e'); return false; }
  }

  // ── RPC ───────────────────────────────────────────────────────
  Future<bool> sendRpc(String method, dynamic params) async {
    final endpoints = [
      '/api/rpc/oneway/$deviceId',
      '/api/plugins/rpc/oneway/$deviceId',
    ];
    for (final ep in endpoints) {
      try {
        final r = await http.post(
          Uri.https(host, ep), headers: _h,
          body: jsonEncode({'method': method, 'params': params}),
        ).timeout(const Duration(seconds: 10));
        print('[TB] RPC $method @ $ep → ${r.statusCode}');
        if (r.statusCode == 200) return true;
      } catch (e) { print('[TB] RPC error: $e'); }
    }
    return false;
  }

  // ── Latest Telemetry ──────────────────────────────────────────
  Future<Map<String, dynamic>> getLatestTelemetry() async => {};

  // ── Device Active ─────────────────────────────────────────────
  Future<bool> isDeviceActive() async {
    try {
      final r = await http.get(
        Uri.https(host, '/api/plugins/telemetry/DEVICE/$deviceId/values/attributes/SERVER_SCOPE',
          {'keys': 'active'}), headers: _h).timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) {
        final list = jsonDecode(r.body) as List;
        if (list.isNotEmpty) return list[0]['value'] == true;
      }
    } catch (_) {}
    return false;
  }

  // ── Alarms ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> getAlarms({String status = '', int pageSize = 30}) async {
    try {
      final params = <String, String>{'pageSize': pageSize.toString(), 'page': '0', 'sortOrder': 'DESC'};
      if (status.isNotEmpty) params['searchStatus'] = status;
      final r = await http.get(
        Uri.https(host, '/api/alarm/DEVICE/$deviceId', params),
        headers: _h).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body);
        return ((data['data'] as List?) ?? []).map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (e) { print('[TB] getAlarms error: $e'); }
    return [];
  }

  // ── WebSocket ─────────────────────────────────────────────────
  void connectWebSocket() {
    if (_jwtToken == null) return;
    disconnectWebSocket();
    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('wss://$host/api/ws/plugins/telemetry?token=$_jwtToken'));

      _wsChannel!.sink.add(jsonEncode({
        'tsSubCmds': [],
        'historyCmds': [],
        'attrSubCmds': [
          {'entityType': 'DEVICE', 'entityId': deviceId, 'scope': 'SERVER_SCOPE',  'cmdId': 2},
          {'entityType': 'DEVICE', 'entityId': deviceId, 'scope': 'SHARED_SCOPE',  'cmdId': 3},
          {'entityType': 'DEVICE', 'entityId': deviceId, 'scope': 'CLIENT_SCOPE',  'cmdId': 4},
        ],
      }));

      _wsChannel!.stream.listen(
        _onWsMessage,
        onError: (e) { print('[WS] Error: $e'); _scheduleReconnect(); },
        onDone:  ()  { print('[WS] Disconnected'); _scheduleReconnect(); },
      );
      print('[WS] Connected');
    } catch (e) {
      print('[WS] Connect error: $e');
      _scheduleReconnect();
    }
  }

  void _onWsMessage(dynamic msg) {
    try {
      final json  = jsonDecode(msg as String) as Map<String, dynamic>;
      final subId = json['subscriptionId'] as int? ?? 0;
      final err   = json['errorCode'] as int? ?? 0;

      if (err != 0) {
        print('[WS] subId=$subId error=${json['errorMsg']}');
        // Selesaikan history completer dengan list kosong kalau error
        if (_historyCompleters.containsKey(subId)) {
          _historyCompleters.remove(subId)?.complete([]);
        }
        return;
      }

      final rawData = json['data'] as Map<String, dynamic>?;
      if (rawData == null || rawData.isEmpty) return;

      // Cek apakah ini response untuk historyCmds
      if (_historyCompleters.containsKey(subId)) {
        // Parse history data: {key: [[ts, val], [ts, val], ...]}
        final key = rawData.keys.first;
        final dataList = rawData[key] as List? ?? [];
        final result = dataList.map((item) {
          if (item is List && item.length >= 2) {
            return {
              'ts'   : item[0] is int ? item[0] as int : int.tryParse(item[0].toString()) ?? 0,
              'value': double.tryParse(item[1].toString()) ?? 0.0,
            };
          }
          return {'ts': 0, 'value': 0.0};
        }).where((e) => e['ts'] != 0).toList();

        print('[WS] historyCmds subId=$subId: ${result.length} data points');
        _historyCompleters.remove(subId)?.complete(
          result.cast<Map<String, dynamic>>()
        );
        return;
      }

      final parsed = <String, dynamic>{};
      rawData.forEach((key, val) {
        if (val is List && val.isNotEmpty) {
          final first = val[0];
          if (first is List && first.length >= 2) parsed[key] = first[1];
          else if (first is Map) parsed[key] = first['value'];
        }
      });
      if (parsed.isEmpty) return;
      print('[WS] subId=$subId data=$parsed');

      if (subId == 4) {
        // Simpan ke local history untuk halaman Riwayat
        _saveToLocalHistory(parsed);
        _telemetryController.add(parsed);
      } else {
        _attributeController.add(parsed);
      }
    } catch (e) { print('[WS] Parse error: $e'); }
  }

  void _saveToLocalHistory(Map<String, dynamic> data) {
    final keys = ['ph', 'tds', 'temperature'];
    for (final key in keys) {
      if (data.containsKey(key)) {
        final val = double.tryParse(data[key].toString());
        if (val != null) LocalHistoryService.addEntry(key, val);
      }
    }
  }

  void _scheduleReconnect() =>
      Future.delayed(const Duration(seconds: 5), connectWebSocket);

  void disconnectWebSocket() {
    // Selesaikan semua pending completers sebelum disconnect
    for (final c in _historyCompleters.values) {
      if (!c.isCompleted) c.complete([]);
    }
    _historyCompleters.clear();
    _wsChannel?.sink.close();
    _wsChannel = null;
  }
}
