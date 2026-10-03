import 'package:flutter/material.dart';

/// Colours used across the app shell and the redesigned pages.
///
/// The streaming chrome is dark, so accents have to be bright enough to read
/// against it. [brand] is the single accent for buttons, active tabs, pager
/// dots and indicator bars; [logoGreen] is reserved for the logo tile.
class AppPalette {
  const AppPalette._();

  /// Page background.
  static const Color background = Color(0xFF0D0F1F);

  /// Sidebar, app bar and card surfaces.
  static const Color surface = Color(0xFF151827);
  static const Color surfaceHigh = Color(0xFF1D2033);

  /// Default accent. Red, so every button, active tab, pager dot and
  /// indicator bar shares one colour instead of green and red fighting.
  static const Color brand = Color(0xFFE11D48);
  static const Color brandDark = Color(0xFF9F1239);

  /// The green logo tile. Kept separate from [brand] so rebranding the
  /// interface does not repaint the mark in the app bar and on the login
  /// screen, which is the one place the original green identity still shows.
  static const Color logoGreen = Color(0xFF10D98D);
  static const Color logoGreenDark = Color(0xFF08B877);

  /// Red used for the Downloaded page buttons.
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerBright = Color(0xFFF43F5E);
  static const Color dangerDark = Color(0xFF9F1239);

  /// Primary action buttons (Watch now, See more, Log out, Download).
  ///
  /// These were green until they moved onto the red family; the green
  /// [brand] colour survives only in the logo tile and the rating stars.
  static const Color action = dangerBright;
  static const Color actionDark = dangerDark;

  /// Gradient for the primary action buttons.
  static const LinearGradient actionGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[action, actionDark],
  );

  /// Text colours.
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x73FFFFFF);

  /// Flat red gradient for primary red buttons.
  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: <Color>[dangerBright, dangerDark],
  );
}
