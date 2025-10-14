import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:pdfrx/pdfrx.dart';
import 'pages/login_page.dart';
import 'pages/splash_screen.dart';

/// Entry point for the PSS Security application.
///
/// The application defines a simple theme and shows the [LoginPage] as
/// the initial route.  Once the user has authenticated successfully
/// they will be navigated to the home screen (see login_page.dart).
Future<void> main() async {
  // Ensure that Flutter engine bindings are initialised before
  // interacting with plugins.  This is required when using
  // asynchronous initialisation such as Firebase.  After initialising
  // Firebase, the pdfrx library is also initialised so that PDF
  // documents can be rendered on all supported platforms (Android,
  // iOS, Windows, etc.).
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  pdfrxFlutterInitialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const Color primaryBlue = Color(0xFF5a93a8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color headerColor = Color(0xFF78B1C6);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PSS Security',
      theme: ThemeData(
        // Define the primary colour and use the surface colour for
        // scaffolds instead of the deprecated background field.  The
        // scaffoldBackgroundColor is explicitly set to ensure the
        // overall window background is white.
        colorScheme: ColorScheme.light(
          primary: primaryBlue,
          onPrimary: white,
          surface: white,
        ),
        scaffoldBackgroundColor: white,
        appBarTheme: const AppBarTheme(
          backgroundColor: headerColor,
          foregroundColor: white,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}