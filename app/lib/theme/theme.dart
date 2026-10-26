import 'package:flutter/material.dart';

import 'colors.dart';
import 'text.dart';

ThemeData buildHotziTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: HotziColors.violet).copyWith(
    primary: HotziColors.violet,
    onPrimary: Colors.white,
    secondary: HotziColors.mango,
    onSecondary: HotziColors.ink,
    surface: HotziColors.surface,
    onSurface: HotziColors.ink,
    error: HotziColors.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: HotziColors.ground,
  );
  OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: HotziColors.ink, displayColor: HotziColors.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border(HotziColors.line),
      enabledBorder: border(HotziColors.line),
      focusedBorder: border(HotziColors.violet, 2),
      errorBorder: border(HotziColors.danger),
      focusedErrorBorder: border(HotziColors.danger, 2),
      hintStyle: HotziText.body(16, color: HotziColors.ink3),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? HotziColors.ok : const Color(0xFFA7A1B8),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: HotziColors.violetDeep,
      contentTextStyle: HotziText.body(15, weight: FontWeight.w600, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
