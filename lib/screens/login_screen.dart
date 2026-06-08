import 'package:flutter/material.dart';
import '../services/tb_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading       = false;
  bool _obscure       = true;
  String? _error;

  static const Color kTeal = Color(0xFF3299A0);
  static const Color kDark = Color(0xFF2D5072);

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email dan password wajib diisi');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final ok = await TbService.instance.login(email, password);

    if (!mounted) return;

    if (ok) {
      TbService.instance.connectWebSocket();
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      setState(() {
        _loading = false;
        _error   = 'Login gagal. Cek email dan password ThingsBoard.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              // Logo
              Center(
                child: Column(children: [
                  Image.asset('images/logo.png', height: 90,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.water_drop, size: 90, color: kTeal)),
                  const SizedBox(height: 12),
                  Image.asset('images/text.png', height: 40,
                      errorBuilder: (_, __, ___) =>
                          const Text('HydroMate', style: TextStyle(
                              fontSize: 24, fontWeight: FontWeight.bold, color: kDark))),
                ]),
              ),

              const SizedBox(height: 40),

              const Text('Login ThingsBoard',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kDark),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Masukkan akun ThingsBoard Cloud kamu',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center),

              const SizedBox(height: 30),

              // Email field
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email_outlined, color: kTeal),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kTeal, width: 2),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Password field
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: kTeal),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: kTeal, width: 2),
                  ),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(_error!,
                      style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      textAlign: TextAlign.center),
                ),
              ],

              const SizedBox(height: 24),

              // Login button
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Login',
                        style: TextStyle(fontSize: 16, color: Colors.white,
                            fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),

              // Info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Gunakan akun thingsboard.cloud kamu.\n'
                  'Credentials disimpan di device dan tidak dikirim ke mana-mana.',
                  style: TextStyle(fontSize: 11, color: Colors.teal),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
