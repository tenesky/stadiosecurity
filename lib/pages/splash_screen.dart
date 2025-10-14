import 'package:flutter/material.dart';

import 'login_page.dart';

/// A simple splash screen that shows an animated loader while the
/// application performs its initialisation (e.g. connecting to the
/// database).  Once complete, it navigates to the [LoginPage].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    // Simulate initialization delay.  In a real application you
    // could test connectivity or perform setup here.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            FlutterLogo(size: 80),
            SizedBox(height: 16),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PSS Security wird gestartet...'),
          ],
        ),
      ),
    );
  }
}