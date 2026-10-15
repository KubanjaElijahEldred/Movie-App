import 'package:flutter_test/flutter_test.dart';
import 'package:movies/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Waits for the service's asynchronous bookmark load to settle.
///
/// [AuthService] reads SharedPreferences without exposing a readiness future,
/// so give the mock store a turn to answer before asserting.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('toggling adds then removes a bookmark', () async {
    final AuthService auth = AuthService();

    expect(auth.bookmarkedIds, isEmpty);
    expect(auth.isBookmarked(42), isFalse);

    expect(await auth.toggleBookmark(42), isTrue);
    expect(auth.isBookmarked(42), isTrue);

    expect(await auth.toggleBookmark(42), isFalse);
    expect(auth.isBookmarked(42), isFalse);

    auth.dispose();
  });

  test('a missing id is ignored', () async {
    final AuthService auth = AuthService();
    expect(await auth.toggleBookmark(null), isFalse);
    expect(auth.bookmarkedIds, isEmpty);
    auth.dispose();
  });

  test('a guest bookmark is written under the guest key', () async {
    final AuthService auth = AuthService();
    await auth.toggleBookmark(7);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('user_bookmarks_guest'), <String>['7']);
    auth.dispose();
  });

  test('bookmarks reload for a fresh service on the same device', () async {
    final AuthService first = AuthService();
    await first.toggleBookmark(11);
    await first.toggleBookmark(22);
    first.dispose();

    final AuthService second = AuthService();
    await settle();

    expect(second.isBookmarked(11), isTrue);
    expect(second.isBookmarked(22), isTrue);
    second.dispose();
  });
}
