import 'package:flutter/painting.dart';

import 'colors.dart';

/// Styles de texte du design. Les trois polices sont variables : la graisse
/// passe aussi par l'axe « wght », sinon elle ne serait pas toujours appliquée.
abstract final class HotziText {
  /// Titres et grands chiffres (Bricolage Grotesque).
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w800,
    Color color = HotziColors.ink,
    double? height,
    double letterSpacing = -0.02,
  }) => _style('Bricolage', size, weight, color, height, letterSpacing);

  /// Texte courant (Inter).
  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = HotziColors.ink,
    double? height,
  }) => _style('Inter', size, weight, color, height, 0);

  /// Codes des tickets et valeurs techniques (JetBrains Mono).
  static TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w700,
    Color color = HotziColors.ink,
    double letterSpacing = 0.06,
  }) => _style('JetBrainsMono', size, weight, color, null, letterSpacing);

  static TextStyle _style(
    String family,
    double size,
    FontWeight weight,
    Color color,
    double? height,
    double letterSpacingEm,
  ) => TextStyle(
    fontFamily: family,
    fontSize: size,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: height,
    letterSpacing: size * letterSpacingEm,
  );
}
