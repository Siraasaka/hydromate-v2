import 'package:flutter/material.dart';

class HistorySelectScreen extends StatefulWidget {
  const HistorySelectScreen({super.key});

  @override
  State<HistorySelectScreen> createState() => _HistorySelectScreenState();
}

class _HistorySelectScreenState extends State<HistorySelectScreen> {
  static const Color kTealColor = Color(0xFF3299A0);
  static const Color kDarkBlueColor = Color(0xFF2D5072);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: kTealColor, size: 35),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        title: const Text(
          'PILIH RIWAYAT',
          style: TextStyle(
            color: kTealColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: 2.0,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),

            _buildTile(
              imageWidget: Image.asset(
                  'images/ph.png',
                  width: 45, height: 45, fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.science_outlined, color: kTealColor, size: 45)
              ),
              title: 'Riwayat pH',
              onTap: () => Navigator.pushNamed(context, '/ph_history'),
            ),

            const SizedBox(height: 25),

            _buildTile(
              imageWidget: Image.asset(
                  'images/ppm.png',
                  width: 45, height: 45, fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.water_drop_outlined, color: kTealColor, size: 45)
              ),
              title: 'Riwayat PPM',
              onTap: () => Navigator.pushNamed(context, '/ppm_history'),
            ),

            const SizedBox(height: 25),

            _buildTile(
              imageWidget: Image.asset(
                  'images/suhu.png',
                  width: 45, height: 45, fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.thermostat_outlined, color: kTealColor, size: 45)
              ),
              title: 'Riwayat Suhu',
              onTap: () => Navigator.pushNamed(context, '/temp_history'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile({
    required Widget imageWidget,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            imageWidget,
            const SizedBox(width: 25),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                    color: kDarkBlueColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}