/// Formatting for a title's release date and the time left before it arrives.
///
/// TMDB reports dates as bare `YYYY-MM-DD` strings, and some titles have no
/// date at all. Everything here tolerates a null or malformed value rather than
/// throwing, because a card has to render regardless of what the API returned.
class ReleaseDate {
  ReleaseDate._();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _monthsFull = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// The month and year a date falls in, e.g. `October 2026`.
  static String monthYear(DateTime date) =>
      '${_monthsFull[date.month - 1]} ${date.year}';

  /// Parses a TMDB `YYYY-MM-DD` string, or null when it is missing or invalid.
  static DateTime? parse(String? value) {
    if (value == null) return null;
    final String trimmed = value.trim();
    if (trimmed.length < 10) return null;
    return DateTime.tryParse(trimmed);
  }

  /// A short human date such as `Mar 15, 2026`, or [fallback] when unknown.
  static String format(String? value, {String fallback = 'TBA'}) {
    final DateTime? date = parse(value);
    if (date == null) return fallback;
    return '${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// True when [value] has not been released yet: either its date is in the
  /// future, or no date is known (an announced-but-undated title still counts
  /// as coming soon).
  static bool isUpcoming(String? value, {DateTime? now}) {
    final DateTime? date = parse(value);
    if (date == null) return true;
    return _dateOnly(date).isAfter(_today(now));
  }

  /// How long until [value], phrased for a card: `In 5 days`, `In 3 weeks`,
  /// `In 2 months`, `Out today`. Null when the date is unknown or has passed.
  static String? timeUntil(String? value, {DateTime? now}) {
    final DateTime? date = parse(value);
    if (date == null) return null;
    final int days = _dateOnly(date).difference(_today(now)).inDays;
    if (days < 0) return null;
    if (days == 0) return 'Out today';
    if (days == 1) return 'In 1 day';
    if (days < 14) return 'In $days days';
    if (days < 60) {
      final int weeks = (days / 7).round();
      return weeks <= 1 ? 'In 1 week' : 'In $weeks weeks';
    }
    if (days < 365) {
      final int months = (days / 30).round();
      return months <= 1 ? 'In 1 month' : 'In $months months';
    }
    final int years = (days / 365).round();
    return years <= 1 ? 'In 1 year' : 'In $years years';
  }

  /// Strips the time component so comparisons are made between calendar days
  /// and a release "today" is not already considered in the past.
  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _today(DateTime? now) {
    final DateTime reference = now ?? DateTime.now();
    return DateTime(reference.year, reference.month, reference.day);
  }
}
