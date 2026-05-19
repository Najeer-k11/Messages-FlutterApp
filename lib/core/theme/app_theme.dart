import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme(ColorScheme? dynamicColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: dynamicColor ?? ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      scaffoldBackgroundColor: dynamicColor?.surface ?? Colors.white,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
      ),
    );
  }

  static ThemeData darkTheme(ColorScheme? dynamicColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: dynamicColor ?? ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: dynamicColor?.surface ?? Colors.black87,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
      ),
    );
  }
}
