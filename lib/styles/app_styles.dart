import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color(0xFF2D5072);
  static const Color lightBlueBackground = Color(0xFFCEE7FF);
  static const Color cardGray = Color(0xFFECEEF2);
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color green = Colors.green;
  static const Color red = Colors.red;
}

class AppText {
  static const TextStyle sectionTitle = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 20,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle subtitle = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle body = TextStyle(
    color: AppColors.black,
    fontSize: 14,
  );

  static const TextStyle sensorValue = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 24,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle sensorLabel = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 16,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle logoHino = TextStyle(
    color: AppColors.primaryBlue,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
  static const TextStyle logoSnc = TextStyle(
    color: AppColors.black,
    fontSize: 28,
    fontWeight: FontWeight.bold,
  );
}
