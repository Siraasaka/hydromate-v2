import 'package:flutter/material.dart';
import 'dart:async';
import '../services/tb_service.dart';

const Color kPrimaryTextColor       = Color(0xFF2D5072);
const Color kSecondaryBackgroundColor = Color(0xFFECEEF2);
const Color kTealColor              = Color(0xFF3299A0);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Sensor data ──────────────────────────────────────────────
  String _ph   = '--', _tds = '--', _temp = '--';
  bool   _pump = false, _flow = false;
  int    _pumpMode = 0;
  bool   _isOnline = false;

  // ── Presets ───────────────────────────────────────────────────
  int _currentPresetIndex = 0;
  final List<Map<String, dynamic>> _presets = [
    {'name': 'Bayam',    'range_display': '1260-1610 PPM | 5.5-6.6 pH', 'ppm_min': 1260, 'ppm_max': 1610, 'ph_min': 5.5, 'ph_max': 6.6},
    {'name': 'Selada',   'range_display': '560-840 PPM | 5.5-6.5 pH',   'ppm_min': 560,  'ppm_max': 840,  'ph_min': 5.5, 'ph_max': 6.5},
    {'name': 'Mint',     'range_display': '1400-1680 PPM | 5.5-6.5 pH', 'ppm_min': 1400, 'ppm_max': 1680, 'ph_min': 5.5, 'ph_max': 6.5},
    {'name': 'Kangkung', 'range_display': '1050-1400 PPM | 5.5-6.5 pH', 'ppm_min': 1050, 'ppm_max': 1400, 'ph_min': 5.5, 'ph_max': 6.5},
    {'name': 'Pakcoy',   'range_display': '1050-1400 PPM | 6.5-7.0 pH', 'ppm_min': 1050, 'ppm_max': 1400, 'ph_min': 6.5, 'ph_max': 7.0},
    {'name': 'Sawi',     'range_display': '840-1680 PPM | 5.5-6.8 pH',  'ppm_min': 840,  'ppm_max': 1680, 'ph_min': 5.5, 'ph_max': 6.8},
  ];

  // ── Pump control ──────────────────────────────────────────────
  int  _tempPumpMode   = 0;
  final bool _pumpForceOn    = false;
  bool _pumpForceActive = false; // true = force ON/OFF, false = AUTO

  // ── Calibration ───────────────────────────────────────────────
  final _tdsInputCtrl     = TextEditingController();
  bool  _calActive        = false;
  bool  _calBusy          = false;
  int   _selectedPhStep   = 0;

  // ── Misc ───────────────────────────────────────────────────────
  late Timer _clockTimer;
  DateTime _currentTime = DateTime.now();
  StreamSubscription? _tsSub, _attrSub;

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(minutes: 1),
        (_) { if (mounted) setState(() => _currentTime = DateTime.now()); });
    _loadInitialData();
    _subscribeWS();
  }

  Future<void> _loadInitialData() async {
    final telem = await TbService.instance.getLatestTelemetry();
    final attrs = await TbService.instance.getSharedAttributes();
    final active = await TbService.instance.isDeviceActive();
    if (!mounted) return;
    setState(() {
      _isOnline = active;
      _applyTelemetry(telem);
      _applyAttributes(attrs);
    });
  }

  void _subscribeWS() {
    _tsSub = TbService.instance.telemetryStream.listen((data) {
      if (mounted) setState(() => _applyTelemetry(data));
    });
    _attrSub = TbService.instance.attributeStream.listen((data) {
      if (mounted) {
        setState(() {
        if (data.containsKey('active')) _isOnline = data['active'].toString() == 'true';
        _applyAttributes(data);
      });
      }
    });
  }

  void _applyTelemetry(Map<String, dynamic> d) {
    if (d.containsKey('ph'))          _ph      = _fmt(d['ph']);
    if (d.containsKey('tds'))         _tds     = _fmt(d['tds'], decimal: 0);
    if (d.containsKey('temperature')) _temp    = _fmt(d['temperature']);
    if (d.containsKey('pump'))        _pump    = d['pump'].toString() == 'true';
    if (d.containsKey('flow'))        _flow    = d['flow'].toString() == 'true';
    if (d.containsKey('pump_mode'))   _pumpMode = int.tryParse(d['pump_mode'].toString()) ?? 0;
  }

  void _applyAttributes(Map<String, dynamic> d) {
    // threshold updates are ignored here — used by history screens
  }

  String _fmt(dynamic v, {int decimal = 2}) {
    if (v == null) return '--';
    final n = double.tryParse(v.toString());
    if (n == null) return '--';
    if (decimal == 0) return n.round().toString();
    if (n % 1 == 0) return n.toInt().toString();
    return n.toStringAsFixed(decimal);
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _tsSub?.cancel();
    _attrSub?.cancel();
    _tdsInputCtrl.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildRealtimeCard(),
                const SizedBox(height: 15),
                _buildPresetCard(),
                const SizedBox(height: 15),
                _buildPumpCard(),
                const SizedBox(height: 15),
                _buildCalibrationCard(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    final months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    final dt = _currentTime;
    final timeStr =
        '${dt.day.toString().padLeft(2,'0')} ${months[dt.month-1]} ${dt.year} '
        '• ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')} WIB';

    return Center(child: Column(children: [
      Image.asset('images/text.png', height: 60,
          errorBuilder: (_,__,___) => const Text('HydroMate',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kDark))),
      const SizedBox(height: 10),
      Image.asset('images/logo.png', height: 90,
          errorBuilder: (_,__,___) => const Icon(Icons.water_drop, size: 90, color: kTealColor)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.wifi, size: 16, color: _isOnline ? Colors.green : Colors.red),
        const SizedBox(width: 5),
        Text(_isOnline ? 'Connected' : 'Disconnected',
            style: TextStyle(
                color: _isOnline ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold)),
      ]),
      Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    ]));
  }

  // ── Realtime Card ─────────────────────────────────────────────
  Widget _buildRealtimeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          const Text('Data Real-Time',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
          const SizedBox(height: 12),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: _miniBox('Suhu', '$_temp°C', isFullHeight: true)),
            const SizedBox(width: 10),
            Expanded(child: Column(children: [
              Expanded(child: _miniBox('pH', _ph)),
              const SizedBox(height: 10),
              Expanded(child: _miniBox('PPM', _tds)),
            ])),
          ])),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _statusChip(Icons.waves, 'Flow', _flow),
            const SizedBox(width: 12),
            _statusChip(Icons.water_drop, 'Pompa', _pump),
          ]),
        ]),
      ),
    );
  }

  Widget _miniBox(String title, String value, {bool isFullHeight = false}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: isFullHeight ? 40 : 15),
      decoration: BoxDecoration(
          color: kSecondaryBackgroundColor, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(title, style: const TextStyle(fontSize: 12, color: kPrimaryTextColor)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
      ]),
    );
  }

  Widget _statusChip(IconData icon, String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? kTealColor.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? kTealColor : Colors.grey.shade300),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: active ? kTealColor : Colors.grey),
        const SizedBox(width: 6),
        Text('$label: ${active ? "ON" : "OFF"}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                color: active ? kTealColor : Colors.grey)),
      ]),
    );
  }

  // ── Preset Card ───────────────────────────────────────────────
  Widget _buildPresetCard() {
    final plant = _presets[_currentPresetIndex];
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          const Text('Preset Tanaman',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
              decoration: BoxDecoration(
                  color: kSecondaryBackgroundColor, borderRadius: BorderRadius.circular(15)),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() =>
                      _currentPresetIndex = (_currentPresetIndex - 1 + _presets.length) % _presets.length),
                  child: const Icon(Icons.arrow_back_ios, size: 18, color: Colors.black),
                ),
                Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(plant['name'], textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(plant['range_display'], textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ])),
                GestureDetector(
                  onTap: () => setState(() =>
                      _currentPresetIndex = (_currentPresetIndex + 1) % _presets.length),
                  child: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.black),
                ),
              ]),
            )),
            const SizedBox(width: 10),
            _setButton(() async {
              final ok = await TbService.instance.saveSharedAttributes({
                'preset_name': plant['name'],
                'ph_min' : plant['ph_min'],
                'ph_max' : plant['ph_max'],
                'tds_min': plant['ppm_min'],
                'tds_max': plant['ppm_max'],
              });
              if (mounted) {
                if (ok) {
                  _showSuccess('Preset ${plant['name']} Diterapkan!');
                } else {
                  _showWarning('Gagal menerapkan preset. Cek koneksi.');
                }
              }
            }),
          ]),
        ]),
      ),
    );
  }

  // ── Pump Card ─────────────────────────────────────────────────
  Widget _buildPumpCard() {
    final cycleNames     = ['Siklus Normal', 'Siklus Panjang', 'Always ON'];
    final cycleDurations = ['15 mnt/jam', '30 mnt/jam', 'ON Terus'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(children: [
          const Text('Kontrol Pompa',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
          const SizedBox(height: 15),

          // Pump cycle mode
          Row(children: [
            Expanded(child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: kSecondaryBackgroundColor, borderRadius: BorderRadius.circular(15)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16, color: Colors.black),
                  onPressed: () => setState(() => _tempPumpMode = (_tempPumpMode - 1 + 3) % 3),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(cycleNames[_tempPumpMode],
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                  Text(cycleDurations[_tempPumpMode],
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black),
                  onPressed: () => setState(() => _tempPumpMode = (_tempPumpMode + 1) % 3),
                ),
              ]),
            )),
            const SizedBox(width: 10),
            _setButton(() async {
              final ok = await TbService.instance.sendRpc('setPumpMode', _tempPumpMode);
              if (mounted) {
                if (ok) {
                  _showSuccess('Siklus Diterapkan!');
                } else {
                  _showWarning('RPC gagal terkirim.');
                }
              }
            }),
          ]),

          const SizedBox(height: 20),
          const Text('Pompa Utama',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
          const SizedBox(height: 15),

          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Column(children: [
              // Force mode selector
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _modeChip('AUTO', !_pumpForceActive),
                const SizedBox(width: 8),
                _modeChip('MANUAL', _pumpForceActive),
              ]),
              const SizedBox(height: 15),
              // ON/OFF buttons
              Row(children: [
                _pumpButton(true,  _pump,  _pumpForceActive),
                const SizedBox(width: 12),
                _pumpButton(false, _pump,  _pumpForceActive),
              ]),
            ]),
            const SizedBox(width: 30),
            AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _pump ? 1.0 : 0.3,
              child: Image.asset('images/pump.png', width: 100, height: 100,
                  errorBuilder: (_,__,___) =>
                      Icon(Icons.water_drop, size: 80,
                          color: _pump ? kTealColor : Colors.grey)),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _modeChip(String label, bool active) {
    return GestureDetector(
      onTap: () async {
        setState(() => _pumpForceActive = (label == 'MANUAL'));
        if (label == 'AUTO') {
          await TbService.instance.sendRpc('setPump', 'AUTO');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kTealColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kTealColor : Colors.grey.shade300),
        ),
        child: Text(label,
            style: TextStyle(color: active ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _pumpButton(bool targetOn, bool currentOn, bool enabled) {
    final isThis   = currentOn == targetOn;
    final color    = targetOn ? kTealColor : Colors.red.shade400;
    return GestureDetector(
      onTap: enabled ? () async {
        await TbService.instance.sendRpc('setPump', targetOn);
      } : null,
      child: Container(
        width: 90, height: 55,
        decoration: BoxDecoration(
          color: isThis && enabled ? color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: enabled ? color : Colors.grey.shade200, width: 2.5),
        ),
        child: Center(child: Text(targetOn ? 'ON' : 'OFF',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: enabled ? color : Colors.grey.shade400))),
      ),
    );
  }

  // ── Calibration Card ──────────────────────────────────────────
  Widget _buildCalibrationCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Column(children: [
          const Text('Kalibrasi Sensor',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
          if (_calBusy) ...[
            const SizedBox(height: 8),
            const Text('Perintah dikirim ke ESP32...',
                style: TextStyle(fontSize: 12, color: kTealColor)),
          ],
          const SizedBox(height: 20),

          // pH calibration
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: kSecondaryBackgroundColor, borderRadius: BorderRadius.circular(15)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Kalibrasi Sensor pH',
                  style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
              Row(children: [
                _phCalibBtn(4),
                const SizedBox(width: 8),
                _phCalibBtn(7),
              ]),
            ]),
          ),

          const SizedBox(height: 12),

          // TDS calibration
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(15),
              border: Border.all(color: kSecondaryBackgroundColor, width: 2)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Kalibrasi Sensor\nTDS/PPM',
                  style: TextStyle(fontWeight: FontWeight.bold, color: kPrimaryTextColor)),
              Container(
                width: 130, height: 45,
                decoration: BoxDecoration(
                    color: kSecondaryBackgroundColor, borderRadius: BorderRadius.circular(10)),
                child: TextField(
                  controller: _tdsInputCtrl,
                  enabled: _calActive && !_calBusy,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Masukkan Nilai TDS',
                    hintStyle: TextStyle(fontSize: 9, color: Colors.grey),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 25),

          GestureDetector(
            onTap: _calBusy ? null : () {
              if (!_calActive) {
                setState(() => _calActive = true);
              } else {
                _sendCalibration();
              }
            },
            child: Container(
              width: 200, padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.black12, width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4, offset: const Offset(0, 2))],
              ),
              child: Center(child: _calBusy
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: kTealColor))
                  : Text(_calActive ? 'Kirim Perintah !' : 'Mulai Kalibrasi !',
                      style: const TextStyle(color: Colors.black,
                          fontWeight: FontWeight.bold, fontSize: 15))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _phCalibBtn(int val) {
    final isSelected = _selectedPhStep == val;
    return GestureDetector(
      onTap: () {
        if (!_calActive) { _showWarning("Tekan 'Mulai Kalibrasi !' dulu"); return; }
        if (!_calBusy) {
          setState(() {
          _selectedPhStep = (_selectedPhStep == val) ? 0 : val;
          if (_selectedPhStep != 0) _tdsInputCtrl.clear();
        });
        }
      },
      child: Container(
        width: 60, height: 40,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFBDC3C7) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _calActive ? kTealColor : Colors.grey.shade300, width: 1.5),
        ),
        child: Center(child: Text('pH $val',
            style: TextStyle(
                color: isSelected ? Colors.white : (_calActive ? kTealColor : Colors.grey.shade400),
                fontWeight: FontWeight.bold))),
      ),
    );
  }

  Future<void> _sendCalibration() async {
    String cmd = '';
    if (_selectedPhStep == 4) {
      cmd = 'CAL4';
    } else if (_selectedPhStep == 7) cmd = 'CAL7';
    else if (_tdsInputCtrl.text.isNotEmpty) {
      final ppm = _tdsInputCtrl.text.trim();
      cmd = 'TDSK:$ppm';
    }

    if (cmd.isEmpty) {
      _showWarning('Pilih pH atau masukkan nilai TDS dulu!');
      return;
    }

    setState(() { _calBusy = true; });
    final ok = await TbService.instance.sendRpc('calibrate', cmd);
    if (!mounted) return;

    setState(() {
      _calBusy = false;
      _calActive = false;
      _selectedPhStep = 0;
      _tdsInputCtrl.clear();
    });

    if (ok) {
      _showSuccess('Perintah kalibrasi terkirim!');
    } else {
      _showWarning('Gagal kirim perintah. Cek koneksi.');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  Widget _setButton(VoidCallback? onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: kTealColor,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('Set!',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  void _showWarning(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
      backgroundColor: Colors.orange.shade700,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showSuccess(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.teal.shade500,
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 60),
          const SizedBox(height: 15),
          Text(msg, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white,
                  fontSize: 18, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }
}

const Color kDark = Color(0xFF2D5072);
