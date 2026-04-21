import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
    useMaterial3: true,
  );
}
