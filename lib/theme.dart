import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ألوان التطبيق (مستوحاة من أيقونة التطبيق: أزرق عميق متدرج + أبيض).
class Pal {
  final bool dark;
  const Pal._(this.dark);

  factory Pal.of(BuildContext context) =>
      Pal._(Theme.of(context).brightness == Brightness.dark);

  static const Color accent = Color(0xFF38A9FF);
  static const Color accent2 = Color(0xFF22D3EE);
  static const Color danger = Color(0xFFFF5C7A);

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [Color(0xFF0A45B8), Color(0xFF1C9BFF)],
  );

  Color get bg => dark ? const Color(0xFF060C22) : const Color(0xFFF1F5FF);
  Color get bgTop => dark ? const Color(0xFF0B1A4A) : const Color(0xFFD9E7FF);
  Color get surface => dark ? const Color(0xFF111B42) : Colors.white;
  Color get surfaceHigh =>
      dark ? const Color(0xFF18265C) : const Color(0xFFE6EEFF);
  Color get field => dark ? const Color(0xFF0C1535) : const Color(0xFFF3F7FF);
  Color get bubble => dark ? const Color(0xFF17235A) : Colors.white;
  Color get border =>
      dark ? const Color(0x26FFFFFF) : const Color(0x1F0A45B8);
  Color get text => dark ? Colors.white : const Color(0xFF0B1A3F);
  Color get textDim =>
      dark ? const Color(0xFF9FB1E0) : const Color(0xFF55658F);
  Color get glow => dark ? const Color(0x331C9BFF) : const Color(0x2238A9FF);
  Color get shadow =>
      dark ? const Color(0x66000000) : const Color(0x180A45B8);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = Pal._(dark);

  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1C7BFF),
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFF5AB4FF) : const Color(0xFF0A45B8),
    surface: p.surface,
    onSurface: p.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: p.text,
      iconTheme: IconThemeData(color: p.text),
      titleTextStyle: TextStyle(
        color: p.text,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF223170) : const Color(0xFF0B1A3F),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}

// ---------------------------------------------------------------------------
// حفظ وضع الثيم (داكن / فاتح)
// ---------------------------------------------------------------------------

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.dark);

Future<void> loadThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('theme');
    if (v == 'light') themeNotifier.value = ThemeMode.light;
    if (v == 'dark') themeNotifier.value = ThemeMode.dark;
  } catch (_) {}
}

Future<void> toggleThemeMode() async {
  final next = themeNotifier.value == ThemeMode.dark
      ? ThemeMode.light
      : ThemeMode.dark;
  themeNotifier.value = next;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme', next == ThemeMode.dark ? 'dark' : 'light');
  } catch (_) {}
}
