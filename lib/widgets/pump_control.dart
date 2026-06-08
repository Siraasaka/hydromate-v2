import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class PumpControl extends StatelessWidget {
  final Map<String, String> currentCycle;
  final bool isPumpOn;
  final VoidCallback onLeftArrowPressed;
  final VoidCallback onRightArrowPressed;
  final VoidCallback onSetPressed;
  final VoidCallback onStatusToggle;
  final VoidCallback onPumpImagePressed;

  const PumpControl({
    super.key,
    required this.currentCycle,
    required this.isPumpOn,
    required this.onLeftArrowPressed,
    required this.onRightArrowPressed,
    required this.onSetPressed,
    required this.onStatusToggle,
    required this.onPumpImagePressed,
  });

  @override
  Widget build(BuildContext context) {
    const Color kBlackTextColor = Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(
          child: Text(
            'Pompa Utama',
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: kPrimaryTextColor),
          ),
        ),
        const SizedBox(height: 15),

        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                decoration: BoxDecoration(
                  color: kSecondaryBackgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 16, color: kBlackTextColor),
                      onPressed: onLeftArrowPressed,
                    ),
                    Column(
                      children: [
                        Text(currentCycle['name']!,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: kBlackTextColor)),
                        Text(currentCycle['duration']!,
                            style: const TextStyle(fontSize: 12, color: kBlackTextColor)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 16, color: kBlackTextColor),
                      onPressed: onRightArrowPressed,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: onSetPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Set!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),

        const SizedBox(height: 20),

        Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Status Pompa',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kPrimaryTextColor,
                        height: 1.0),
                  ),
                  const SizedBox(height: 30),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                    decoration: BoxDecoration(
                      color: kSecondaryBackgroundColor,
                      border: Border.all(
                        color: isPumpOn ? Colors.teal : Colors.grey.shade400, // Abu-abu jika OFF
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPumpOn ? 'ON' : 'OFF',
                      style: TextStyle(
                        color: isPumpOn ? Colors.teal.shade700 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 40),

              AnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: isPumpOn ? 1.0 : 0.3, // Lebih redup saat OFF
                child: Image.asset(
                  'images/pump.png',
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}