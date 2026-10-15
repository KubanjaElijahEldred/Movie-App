import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:movies/firebase_options.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The OAuth *web* client ID of the `play-it-movies` project.
///
/// On Android, `google_sign_in` needs this id as its `serverClientId` so the
/// returned ID token is accepted by Firebase Auth. It is the `client_type: 3`
/// entry in `android/app/google-services.json` (a public client identifier,
/// not a secret). iOS reads its own client id from the bundled
/// `GoogleService-Info.plist`, and web uses Firebase's popup flow which needs
/// no client id here.
const String _googleServerClientId =
    '478726185470-qtvnhjfr23ct955qrde1s01licv2okvg.apps.googleusercontent.com';

/// Email/password authentication backed by Firebase Auth.
///
/// The whole app shares one instance through `ChangeNotifierProvider` in
/// `main.dart`, so any screen can read the current user with
/// `context.watch<AuthService>()` and gate protected actions with
/// `ensureSignedIn(context)`.
///
/// Firebase is initialised lazily and defensively: if no real Firebase project
/// has been configured yet (see `lib/firebase_options.dart`), [_firebase] stays
/// null and every auth attempt returns a clear "not configured" message rather
/// than crashing.
class AuthService extends ChangeNotifier {
  AuthService() {
    FirebaseAuth? auth;
    try {
      auth = FirebaseAuth.instance;
    } catch (error) {
      debugPrint('Firebase Auth is unavailable: $error');
      auth = null;
    }
    _firebase = auth;
    _authSubscription = _firebase?.authStateChanges().listen(_handleAuthChange);
    // With no auth backend the state stream never emits, so load the guest
    // bookmarks directly rather than losing them.
    if (_firebase == null) {
      _loadBookmarks();
    }
  }

  /// Initialises Firebase once at startup.
  ///
  /// Safe to call before a real project exists: a failure only disables auth,
  /// it does not stop the app from launching.
  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint(
        'Firebase is not configured yet. Run "flutterfire configure" to '
        'connect a Firebase project. Details: $error',
      );
    }
  }

  late final FirebaseAuth? _firebase;
  StreamSubscription<User?>? _authSubscription;
  bool _googleInitialized = false;

  /// Set once [dispose] runs. The loaders below complete asynchronously, so
  /// without this they could call `notifyListeners` on a disposed notifier.
  bool _disposed = false;

  User? _user;
  bool _busy = false;
  String? _errorMessage;
  Map<int, int> _ratings = <int, int>{};
  Set<int> _bookmarks = <int>{};

  /// The signed in user, or null when browsing as a guest.
  User? get user => _user;

  bool get isLoggedIn => _user != null;

  bool get isBusy => _busy;

  /// The email of the signed in user, if any.
  String? get email => _user?.email;

  /// A friendly name to show in the UI.
  String get displayName {
    final String? name = _user?.displayName;
    if (name != null && name.isNotEmpty) return name;
    final String? address = _user?.email;
    if (address != null && address.contains('@')) {
      return address.split('@').first;
    }
    return 'Guest';
  }

  /// The account's profile photo, when the provider supplied one (Google
  /// accounts usually have one; email/password accounts do not).
  String? get photoUrl => _user?.photoURL;

  /// A single uppercase letter to stand in for the avatar when there is no
  /// profile photo. Taken from the email, falling back to the display name.
  String get initial {
    final String? address = _user?.email;
    if (address != null && address.trim().isNotEmpty) {
      return address.trim()[0].toUpperCase();
    }
    final String name = displayName;
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// True once Firebase Auth is reachable. False means the project has not
  /// been configured yet.
  bool get isAvailable => _firebase != null;

  /// The most recent error message, ready to show to the user.
  String? get errorMessage => _errorMessage;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Signs in an existing account. Returns true on success.
  Future<bool> signIn({required String email, required String password}) {
    return _run(
      () => _firebase!
          .signInWithEmailAndPassword(email: email.trim(), password: password),
    );
  }

  /// Creates a new account and signs it in. Returns true on success.
  Future<bool> signUp({required String email, required String password}) {
    return _run(() async {
      final UserCredential credential = await _firebase!
          .createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final String name = email.trim().split('@').first;
      await credential.user?.updateDisplayName(name);
    });
  }

  /// Signs in (or creates) an account with Google.
  ///
  /// On the web this uses Firebase's popup flow; on Android and iOS it uses
  /// the native Google Sign-In sheet and exchanges the ID token for a Firebase
  /// credential.
  Future<bool> signInWithGoogle() async {
    if (_firebase == null) {
      _errorMessage = 'Authentication is not set up yet. Add your Firebase '
          'project (run "flutterfire configure") and try again.';
      notifyListeners();
      return false;
    }

    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final UserCredential credential;
      if (kIsWeb) {
        final GoogleAuthProvider provider = GoogleAuthProvider();
        provider.setCustomParameters(<String, String>{
          'prompt': 'select_account',
        });
        credential = await _firebase!.signInWithPopup(provider);
      } else {
        await _ensureGoogleInitialized();
        final GoogleSignInAccount account =
            await GoogleSignIn.instance.authenticate();
        final String? idToken = account.authentication.idToken;
        if (idToken == null) {
          throw const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError,
            description: 'Google did not return an ID token.',
          );
        }
        credential = await _firebase!.signInWithCredential(
          GoogleAuthProvider.credential(idToken: idToken),
        );
      }

      _busy = false;
      notifyListeners();
      return credential.user != null;
    } on GoogleSignInException catch (error) {
      _busy = false;
      // A user closing the Google sheet is not an error worth surfacing.
      _errorMessage = error.code == GoogleSignInExceptionCode.canceled
          ? null
          : 'Google sign in failed: ${error.description ?? error.code.name}';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (error) {
      _busy = false;
      _errorMessage = _describe(error);
      notifyListeners();
      return false;
    } catch (error) {
      _busy = false;
      _errorMessage = 'Google sign in is unavailable. Please try again.';
      debugPrint('Google sign in error: $error');
      notifyListeners();
      return false;
    }
  }

  /// Initialises the native Google Sign-In plugin once, before the first
  /// interactive authentication on Android and iOS.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;

    final FirebaseOptions options = DefaultFirebaseOptions.currentPlatform;
    String? clientId;
    String? serverClientId;
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // Falls back to the bundled GoogleService-Info.plist when null.
      clientId = options.iosClientId;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      serverClientId = _googleServerClientId;
    }

    await GoogleSignIn.instance.initialize(
      clientId: clientId,
      serverClientId: serverClientId,
    );
    _googleInitialized = true;
  }

  /// Signs the current user out. Browsing stays available afterwards.
  Future<void> signOut() async {
    if (!kIsWeb && _googleInitialized) {
      try {
        await GoogleSignIn.instance.signOut();
      } catch (error) {
        debugPrint('Google sign out failed: $error');
      }
    }
    try {
      await _firebase?.signOut();
    } catch (error) {
      debugPrint('Sign out failed: $error');
    }
    _ratings = <int, int>{};
    _bookmarks = <int>{};
    _errorMessage = null;
    notifyListeners();
  }

  /// The rating this user gave [movieId], or null if they have not rated it.
  int? ratingFor(int? movieId) => movieId == null ? null : _ratings[movieId];

  /// Records a 1-5 star rating for [movieId] and persists it for this user.
  ///
  /// Returns false when nobody is signed in or the movie id is missing.
  Future<bool> rateMovie(int? movieId, int stars) async {
    final User? user = _user;
    if (user == null || movieId == null || stars < 1 || stars > 5) return false;

    _ratings = <int, int>{..._ratings, movieId: stars};
    notifyListeners();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _ratingsKey(user.uid),
        jsonEncode(
          _ratings.map((int key, int value) => MapEntry(key.toString(), value)),
        ),
      );
    } catch (error) {
      debugPrint('Could not persist rating: $error');
    }
    return true;
  }

  static String _ratingsKey(String uid) => 'user_ratings_$uid';

  /// The ids the current user (or the signed-out guest) has bookmarked.
  List<int> get bookmarkedIds => _bookmarks.toList(growable: false);

  /// Whether the current user has bookmarked [movieId].
  bool isBookmarked(int? movieId) =>
      movieId != null && _bookmarks.contains(movieId);

  /// Adds or removes [movieId] from the current user's bookmarks and persists
  /// the change, so it survives a restart and follows the account across
  /// devices where the same sign-in is used.
  ///
  /// Returns true when the title was added, false when it was removed. Returns
  /// false without changing anything when no id is given.
  Future<bool> toggleBookmark(int? movieId) async {
    if (movieId == null) return false;

    final Set<int> next = <int>{..._bookmarks};
    final bool added = next.add(movieId);
    if (!added) next.remove(movieId);

    _bookmarks = next;
    notifyListeners();

    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _bookmarksKey(),
        _bookmarks.map((int id) => id.toString()).toList(),
      );
    } catch (error) {
      debugPrint('Could not persist bookmark: $error');
    }
    return added;
  }

  /// Bookmarks are namespaced per account, with the signed-out case under a
  /// fixed guest key so a device still remembers guest bookmarks. Keeping the
  /// guest list separate means signing in never leaks another account's saves.
  String _bookmarksKey() => 'user_bookmarks_${_user?.uid ?? 'guest'}';

  Future<void> _loadBookmarks() async {
    final String key = _bookmarksKey();
    Set<int> loaded = <int>{};
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? raw = prefs.getStringList(key);
      if (raw != null) {
        loaded = raw.map(int.tryParse).whereType<int>().toSet();
      }
    } catch (error) {
      debugPrint('Could not load bookmarks: $error');
    }

    // A different user may have signed in, or the service may have been
    // disposed, while the read was in flight.
    if (_disposed || _bookmarksKey() != key) return;
    _bookmarks = loaded;
    notifyListeners();
  }

  void _handleAuthChange(User? user) {
    _user = user;
    _ratings = <int, int>{};
    _bookmarks = <int>{};
    _errorMessage = null;
    notifyListeners();
    if (user != null) _loadRatings(user.uid);
    _loadBookmarks();
  }

  Future<void> _loadRatings(String uid) async {
    Map<int, int> loaded = <int, int>{};
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_ratingsKey(uid));
      if (raw != null) {
        final Map<String, dynamic> decoded =
            jsonDecode(raw) as Map<String, dynamic>;
        loaded = decoded.map(
          (String key, dynamic value) =>
              MapEntry(int.parse(key), (value as num).toInt()),
        );
      }
    } catch (error) {
      debugPrint('Could not load ratings: $error');
    }

    // A different user may have signed in, or the service may have been
    // disposed, while the read was in flight.
    if (_disposed || _user?.uid != uid) return;
    _ratings = loaded;
    notifyListeners();
  }

  Future<bool> _run(Future<void> Function() action) async {
    if (_firebase == null) {
      _errorMessage = 'Authentication is not set up yet. Add your Firebase '
          'project (run "flutterfire configure") and try again.';
      notifyListeners();
      return false;
    }

    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      _busy = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (error) {
      _busy = false;
      _errorMessage = _describe(error);
      notifyListeners();
      return false;
    } catch (error) {
      _busy = false;
      _errorMessage = 'Something went wrong. Please try again.';
      debugPrint('Auth error: $error');
      notifyListeners();
      return false;
    }
  }

  static String _describe(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'operation-not-allowed':
        return 'Email sign-in is disabled for this project.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSubscription?.cancel();
    super.dispose();
  }
}
