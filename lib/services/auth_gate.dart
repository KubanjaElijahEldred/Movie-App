import 'package:flutter/material.dart';
import 'package:movies/screens/login.dart';
import 'package:movies/services/auth_service.dart';
import 'package:provider/provider.dart';

/// Guards an action that needs an account (downloading, rating).
///
/// Returns true immediately when a user is already signed in. Otherwise it
/// opens the sign in screen and reports whether the user completed it, so the
/// caller can continue the action they originally tapped.
///
/// Callers must re-check `mounted` after awaiting this, because it can span a
/// navigation.
Future<bool> ensureSignedIn(BuildContext context) async {
  final AuthService auth = context.read<AuthService>();
  if (auth.isLoggedIn) return true;

  final bool? signedIn = await Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(builder: (_) => const LoginScreen()),
  );
  return signedIn == true;
}
