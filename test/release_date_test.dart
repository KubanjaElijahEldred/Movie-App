import 'package:flutter_test/flutter_test.dart';
import 'package:movies/modal_class/release_date.dart';

void main() {
  // A fixed "today" so the countdown assertions never depend on the clock.
  final DateTime now = DateTime(2026, 6, 15);

  group('format', () {
    test('renders a short human date', () {
      expect(ReleaseDate.format('2026-03-05'), 'Mar 5, 2026');
      expect(ReleaseDate.format('2027-12-31'), 'Dec 31, 2027');
    });

    test('falls back when the date is missing or malformed', () {
      expect(ReleaseDate.format(null), 'TBA');
      expect(ReleaseDate.format(''), 'TBA');
      expect(ReleaseDate.format('not-a-date'), 'TBA');
    });
  });

  group('isUpcoming', () {
    test('is true for a future date', () {
      expect(ReleaseDate.isUpcoming('2026-07-01', now: now), isTrue);
    });

    test('is false for a past date', () {
      expect(ReleaseDate.isUpcoming('2026-01-01', now: now), isFalse);
    });

    test('treats today as released, and an unknown date as upcoming', () {
      expect(ReleaseDate.isUpcoming('2026-06-15', now: now), isFalse);
      expect(ReleaseDate.isUpcoming(null, now: now), isTrue);
    });
  });

  group('timeUntil', () {
    test('phrases days, weeks, months and years', () {
      expect(ReleaseDate.timeUntil('2026-06-15', now: now), 'Out today');
      expect(ReleaseDate.timeUntil('2026-06-16', now: now), 'In 1 day');
      expect(ReleaseDate.timeUntil('2026-06-20', now: now), 'In 5 days');
      expect(ReleaseDate.timeUntil('2026-07-06', now: now), 'In 3 weeks');
      expect(ReleaseDate.timeUntil('2026-08-14', now: now), 'In 2 months');
      expect(ReleaseDate.timeUntil('2027-06-15', now: now), 'In 1 year');
    });

    test('returns null once the date has passed or is unknown', () {
      expect(ReleaseDate.timeUntil('2026-06-14', now: now), isNull);
      expect(ReleaseDate.timeUntil(null, now: now), isNull);
    });
  });
}
