import 'package:flutter/material.dart';
import 'package:movies/constants/app_theme.dart';
import 'package:movies/services/auth_service.dart';
import 'package:provider/provider.dart';

/// Email/password sign in and sign up, backed by Firebase Auth.
///
/// Shown whenever a guest taps a protected action (download, rate) or picks
/// "Sign in" from settings. Pops with `true` once authentication succeeds, so
/// the caller can continue the action that opened it. Closing the screen
/// returns `false` and leaves the user browsing as a guest.
///
/// [themeData] is kept for older call sites that still pass a theme; the screen
/// styles itself from [AppPalette] regardless.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.themeData});

  final ThemeData? themeData;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _isSignUp = false;
  bool _obscurePassword = true;

  static final RegExp _emailPattern =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _confirm.clear();
    });
    context.read<AuthService>().clearError();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final AuthService auth = context.read<AuthService>();
    final bool ok = _isSignUp
        ? await auth.signUp(email: _email.text, password: _password.text)
        : await auth.signIn(email: _email.text, password: _password.text);

    if (!mounted) return;
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final AuthService auth = context.watch<AuthService>();
    final String? error = auth.errorMessage;

    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Keep browsing',
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const Text(
          'Play It',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _header(),
                    const SizedBox(height: 28),
                    _emailField(),
                    const SizedBox(height: 14),
                    _passwordField(),
                    if (_isSignUp) ...<Widget>[
                      const SizedBox(height: 14),
                      _confirmField(),
                    ],
                    if (error != null) ...<Widget>[
                      const SizedBox(height: 16),
                      _errorBanner(error),
                    ],
                    const SizedBox(height: 22),
                    _submitButton(auth),
                    const SizedBox(height: 18),
                    _divider(),
                    const SizedBox(height: 18),
                    _googleButton(auth),
                    const SizedBox(height: 16),
                    _modeSwitch(auth),
                    const SizedBox(height: 24),
                    const Text(
                      'Browsing is free. An account is only needed to download '
                      'movies and save your ratings.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppPalette.textMuted,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: <Widget>[
        Container(
          width: 62,
          height: 62,
          decoration: BoxDecoration(
            color: AppPalette.brand.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Icon(
            Icons.local_movies,
            color: AppPalette.brand,
            size: 32,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _isSignUp ? 'Create your account' : 'Welcome back',
          style: const TextStyle(
            color: AppPalette.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _isSignUp
              ? 'Sign up with your email to start downloading and rating.'
              : 'Sign in with your email to continue.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13.5,
          ),
        ),
      ],
    );
  }

  Widget _emailField() {
    return TextFormField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      autofillHints: const <String>[AutofillHints.email],
      textInputAction: TextInputAction.next,
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: _decoration(
        label: 'Email',
        icon: Icons.alternate_email,
      ),
      validator: (String? value) {
        final String email = (value ?? '').trim();
        if (email.isEmpty) return 'Enter your email address';
        if (!_emailPattern.hasMatch(email)) return 'Enter a valid email address';
        return null;
      },
    );
  }

  Widget _passwordField() {
    return TextFormField(
      controller: _password,
      obscureText: _obscurePassword,
      autofillHints: const <String>[AutofillHints.password],
      textInputAction:
          _isSignUp ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) {
        if (!_isSignUp) _submit();
      },
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: _decoration(
        label: 'Password',
        icon: Icons.lock_outline,
        suffix: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            size: 20,
            color: AppPalette.textMuted,
          ),
          onPressed: () =>
              setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      validator: (String? value) {
        final String password = value ?? '';
        if (password.isEmpty) return 'Enter your password';
        if (password.length < 6) {
          return 'Use at least 6 characters';
        }
        return null;
      },
    );
  }

  Widget _confirmField() {
    return TextFormField(
      controller: _confirm,
      obscureText: _obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) => _submit(),
      style: const TextStyle(color: AppPalette.textPrimary),
      decoration: _decoration(
        label: 'Confirm password',
        icon: Icons.lock_reset,
      ),
      validator: (String? value) {
        if (value != _password.text) return 'Passwords do not match';
        return null;
      },
    );
  }

  InputDecoration _decoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppPalette.textMuted),
      prefixIcon: Icon(icon, color: AppPalette.textMuted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppPalette.surfaceHigh,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppPalette.brand, width: 1.4),
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppPalette.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppPalette.danger.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, color: AppPalette.dangerBright, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppPalette.dangerBright,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _submitButton(AuthService auth) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: auth.isBusy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.brand.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: auth.isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _isSignUp ? 'Create account' : 'Sign in',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _divider() {
    return const Row(
      children: <Widget>[
        Expanded(child: Divider(color: AppPalette.surfaceHigh, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: TextStyle(color: AppPalette.textMuted, fontSize: 12.5),
          ),
        ),
        Expanded(child: Divider(color: AppPalette.surfaceHigh, thickness: 1)),
      ],
    );
  }

  Widget _googleButton(AuthService auth) {
    return SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: auth.isBusy ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.textPrimary,
          side: const BorderSide(color: AppPalette.surfaceHigh),
          backgroundColor: AppPalette.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _GoogleGlyph(),
            SizedBox(width: 12),
            Text(
              'Continue with Google',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppPalette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signInWithGoogle() async {
    FocusScope.of(context).unfocus();
    final AuthService auth = context.read<AuthService>();
    final bool ok = await auth.signInWithGoogle();
    if (!mounted) return;
    if (ok) Navigator.of(context).pop(true);
  }

  Widget _modeSwitch(AuthService auth) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
          _isSignUp ? 'Already have an account?' : 'New to Play It?',
          style: const TextStyle(
            color: AppPalette.textSecondary,
            fontSize: 13.5,
          ),
        ),
        TextButton(
          onPressed: auth.isBusy ? null : _toggleMode,
          style: TextButton.styleFrom(
            foregroundColor: AppPalette.brand,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: Text(
            _isSignUp ? 'Sign in' : 'Create one',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// A lightweight Google "G" mark drawn from the app's bundled Product Sans
/// font, so the button needs no image asset.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: const Text(
        'G',
        style: TextStyle(
          color: Color(0xFF4285F4),
          fontSize: 16,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}
