/// Mise en forme des montants, durées et dates en français.
abstract final class Format {
  /// « 2 200 FCFA », avec une espace fine insécable entre les milliers.
  /// [plain] remplace les espaces spéciales par des espaces simples (PDF).
  static String fcfa(int amount, {bool plain = false}) {
    final separator = plain ? ' ' : ' ';
    final digits = amount.abs().toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(separator);
      grouped.write(digits[i]);
    }
    return '${amount < 0 ? '-' : ''}$grouped${plain ? ' ' : ' '}FCFA';
  }

  /// Forme courte : « 30 min », « 1 h », « 1 h 30 », « 24 h ».
  static String shortDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '$hours h' : '$hours h ${rest.toString().padLeft(2, '0')}';
  }

  /// Forme longue : « 30 minutes », « 1 heure », « 6 heures », « 1 h 30 ».
  static String longDuration(int minutes) {
    if (minutes < 60) return minutes == 1 ? '1 minute' : '$minutes minutes';
    if (minutes % 60 != 0) return shortDuration(minutes);
    final hours = minutes ~/ 60;
    return hours == 1 ? '1 heure' : '$hours heures';
  }

  /// Temps restant : « 4 h 12 », « 38 min », « 45 s ».
  static String remaining(Duration duration) {
    if (duration.inHours > 0) {
      return '${duration.inHours} h ${(duration.inMinutes % 60).toString().padLeft(2, '0')}';
    }
    if (duration.inMinutes > 0) return '${duration.inMinutes} min';
    return '${duration.inSeconds} s';
  }

  static const _days = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  static const _months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];

  /// « Lundi 26 octobre ».
  static String day(DateTime date) => '${_days[date.weekday - 1]} ${date.day} ${_months[date.month - 1]}';

  /// « 14:32 ».
  static String time(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  /// « 14:32 » si c'est aujourd'hui, sinon « 25/10 14:32 ».
  static String when(DateTime date, DateTime now) {
    final sameDay = date.year == now.year && date.month == now.month && date.day == now.day;
    if (sameDay) return time(date);
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${time(date)}';
  }
}
