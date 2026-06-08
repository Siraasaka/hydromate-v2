import 'package:flutter/material.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:badges/badges.dart' as badges;

import 'services/tb_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/history_select_screen.dart';
import 'screens/ppm_history_screen.dart';
import 'screens/ph_history_screen.dart';
import 'screens/temp_history_select.dart';
import 'screens/notification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  OneSignal.initialize('54f3a559-2b78-4d1c-8a96-fb2840d1095c');
  OneSignal.Notifications.requestPermission(true);
  final loggedIn = await TbService.instance.autoLogin();
  runApp(MyApp(startLoggedIn: loggedIn));
}

class MyApp extends StatelessWidget {
  final bool startLoggedIn;
  const MyApp({super.key, required this.startLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydroMate Monitor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false,
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: startLoggedIn ? const MainWrapper() : const LoginScreen(),
      routes: {
        '/home'         : (context) => const MainWrapper(),
        '/login'        : (context) => const LoginScreen(),
        '/notification' : (context) => const NotificationScreen(),
        '/temp_history' : (context) => const TempHistoryScreen(),
        '/ppm_history'  : (context) => const PpmHistoryScreen(),
        '/ph_history'   : (context) => const PhHistoryScreen(),
      },
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});
  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int  _selectedIndex  = 0;
  bool _hasActiveAlarm = false;

  @override
  void initState() {
    super.initState();
    TbService.instance.connectWebSocket();
    _checkAlarms();
    Future.delayed(const Duration(seconds: 30), _pollAlarms);
  }

  Future<void> _checkAlarms() async {
    final alarms = await TbService.instance.getAlarms(status: 'ACTIVE');
    if (mounted) setState(() => _hasActiveAlarm = alarms.isNotEmpty);
  }

  void _pollAlarms() {
    if (!mounted) return;
    _checkAlarms();
    Future.delayed(const Duration(seconds: 30), _pollAlarms);
  }

  @override
  void dispose() {
    TbService.instance.disconnectWebSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // FIX: NotificationScreen tidak pakai IndexedStack — rebuild tiap kali tab dibuka
      // Jadi _loadAlarms() selalu dipanggil fresh
      body: _selectedIndex == 2
          ? const NotificationScreen()
          : IndexedStack(
              index: _selectedIndex,
              children: const [HomeScreen(), HistorySelectScreen()],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF3299A0),
        onTap: (index) {
          setState(() => _selectedIndex = index);
          if (index == 2) _checkAlarms();
        },
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Beranda'),
          const BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Riwayat'),
          BottomNavigationBarItem(
            icon: badges.Badge(
              showBadge: _hasActiveAlarm,
              badgeStyle: const badges.BadgeStyle(badgeColor: Colors.red),
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifikasi',
          ),
        ],
      ),
    );
  }
}
