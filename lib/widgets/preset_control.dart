import 'package:flutter/material.dart';
import '../screens/home_screen.dart';

class PresetControl extends StatelessWidget {
  final Map<String, String> currentPreset;
  final VoidCallback onLeftArrowPressed;
  final VoidCallback onRightArrowPressed;
  final VoidCallback onSetPressed;

  const PresetControl({
    super.key,
    required this.currentPreset,
    required this.onLeftArrowPressed,
    required this.onRightArrowPressed,
    required this.onSetPressed,
  });

  @override
  Widget build(BuildContext context) {
    const Color kBlackTextColor = Colors.black87;

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
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
                    Text(
                        currentPreset['name']!,
                        style: const TextStyle(fontWeight: FontWeight.bold, color: kBlackTextColor)
                    ),
                    Text(
                        currentPreset['range']!,
                        style: const TextStyle(fontSize: 12, color: kBlackTextColor)
                    ),
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
          child: const Text('Set!', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}