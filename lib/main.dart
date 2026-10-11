import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'home_screen.dart';
import 'services.dart';
import 'theme.dart';

/// نفس إعدادات مشروع Firebase الأصلي (spot-7ed0b) — تُستخدم فقط إذا لم يتوفر
/// google-services.json أثناء البناء.
const FirebaseOptions _fallbackOptions = FirebaseOptions(
  apiKey: 'AIzaSyCmd1s6LS5In8jb512UOC32sNXJUnjh2Zo',
  appId: '1:245242854608:android:b00933ba365827e65db2d5',
  messagingSenderId: '245242854608',
  projectId: 'spot-7ed0b',
  storageBucket: 'spot-7ed0b.firebasestorage.app',
);

Future<void> _initFirebase() async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: _fallbackOptions);
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  await loadThemeMode();
  // تسجيل دخول مجهول مسبق؛ الفشل هنا غير حرج (يُعاد المحاولة عند أول إجراء).
  ensureUser().ignore();
  runApp(const AnonymousChatApp());
}

class AnonymousChatApp extends StatelessWidget {
  const AnonymousChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'دردشة مجهولة',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        );
      },
    );
  }
}