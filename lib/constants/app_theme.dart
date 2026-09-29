import 'package:flutter/material.dart';

/// Colours used across the app shell and the redesigned pages.
///
/// The streaming chrome is dark, so accents have to be bright enough to read
/// against it: [brand] for the default accent, [gold] for the home page genre
/// cards and [danger] for the Downloaded page actions.
class AppPalette {
  const AppPalette._();

  /// Page background.
  static const Color background = Color(0xFF0D0F1F);

  /// Sidebar, app bar and card surfaces.
  static const Color surface = Color(0xFF151827);
  static const Color surfaceHigh = Color(0xFF1D2033);

  /// Default accent, matching the original green branding.
  static const Color brand = Color(0xFF10D98D);
  static const Color brandDark = Color(0xFF08B877);

  /// The yellow used for the home page genre cards.
  static const Color gold = Color(0xFFFACC15);
  static const Color goldBright = Color(0xFFFFE066);
  static const Color goldDeep = Color(0xFFB8860B);

  /// Red used for the Downloaded page buttons.
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerBright = Color(0xFFF43F5E);
  static const Color dangerDark = Color(0xFF9F1239);

  /// Text colours.
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x73FFFFFF);

  /// The yellow gradient that sits behind each genre row on the home page.
  ///
  /// Painted over the near-black background the leading stop composites to
  /// roughly RGB(85,72,28), which is a clearly warm card without competing
  /// with the posters inside it.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[Color(0x4DFACC15), Color(0x2EFFE066), Color(0x1AFACC15)],
  );

  /// Flat red gradient for primary red buttons.
  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[dangerBright, dangerDark],
  );

  /// Border for the highlighted genre cards.
  static BoxBorder goldBorder({double width = 1.5, double radius = 18}) {
    return Border.all(color: gold.withValues(alpha: 0.75), width: width);
  }

  /// Soft shadow used to make the genre cards look lifted.
  static List<BoxShadow> goldShadow({double opacity = 0.3}) {
    return <BoxShadow>[
      BoxShadow(
        color: gold.withValues(alpha: opacity),
        blurRadius: 20,
        spreadRadius: -4,
        offset: const Offset(0, 6),
      ),
    ];
  }
}
