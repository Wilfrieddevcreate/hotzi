import 'dart:math';

/// Codes d'accès : mêmes règles que la bibliothèque réseau Kotlin
/// (8 caractères, ni 0/O ni 1/I, soit 32^8 ≈ 10^12 combinaisons).
abstract final class TicketCodes {
  static const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const length = 8;

  static final _random = Random.secure();

  static String generate() =>
      String.fromCharCodes(List.generate(length, (_) => alphabet.codeUnitAt(_random.nextInt(alphabet.length))));

  /// « k7qm-4xpa » ou « K7QM 4XPA » deviennent « K7QM4XPA ».
  static String normalize(String input) => input.toUpperCase().replaceAll(RegExp(r'[-\s.]'), '');

  static String format(String code) => code.length == length ? '${code.substring(0, 4)}-${code.substring(4)}' : code;
}
