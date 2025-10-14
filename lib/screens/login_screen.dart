import 'package:flutter/material.dart';
import '../models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A simple login screen that validates a user's credentials against
/// a provided list of [users]. On successful login the [onLogin]
/// callback is invoked with the authenticated user.
class LoginScreen extends StatefulWidget {
  final List<User> users;
  final void Function(User user) onLogin;

  const LoginScreen({
    Key? key,
    required this.users,
    required this.onLogin,
  }) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  // Variables to hold game settings loaded from preferences.
  bool _appActive = true;
  String _season = '';
  String _guestTeam = '';
  String _competition = '';
  String? _gameInfo;
  bool _loadingSettings = true;
  bool _showLoginFields = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Loads stored settings from SharedPreferences and configures the
  /// login screen accordingly. If the app is inactive the login
  /// fields are hidden until the user explicitly taps the admin login
  /// link.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bool active = prefs.getBool('app_active') ?? true;
    final String season = prefs.getString('season') ?? '';
    final String guest = prefs.getString('guest_team') ?? '';
    final String competition = prefs.getString('competition') ?? '';
    String? dateStr;
    final String? storedDate = prefs.getString('game_date');
    final String? storedTime = prefs.getString('game_time');
    if (storedDate != null) {
      final DateTime? dt = DateTime.tryParse(storedDate);
      if (dt != null) {
        final day = dt.day.toString().padLeft(2, '0');
        final month = dt.month.toString().padLeft(2, '0');
        final year = dt.year.toString();
        dateStr = '$day.$month.$year';
      }
    }
    String? info;
    if (season.isNotEmpty || guest.isNotEmpty || competition.isNotEmpty || storedDate != null) {
      final buffer = StringBuffer();
      if (season.isNotEmpty) buffer.write('Saison: $season\n');
      buffer.write('Heim: 1. FC Lokomotive Leipzig\n');
      if (guest.isNotEmpty) buffer.write('Gast: $guest\n');
      if (competition.isNotEmpty) buffer.write('Wettbewerb: $competition\n');
      if (dateStr != null) {
        if (storedTime != null) {
          buffer.write('Datum & Uhrzeit: $dateStr $storedTime');
        } else {
          buffer.write('Datum: $dateStr');
        }
      }
      info = buffer.toString().trim();
    }
    setState(() {
      _appActive = active;
      _season = season;
      _guestTeam = guest;
      _competition = competition;
      _gameInfo = info;
      _loadingSettings = false;
      _showLoginFields = active;
    });
  }

  void _attemptLogin() {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    try {
      final user = widget.users.firstWhere(
        (u) => u.username == username && u.password == password,
      );
      // If the app is inactive and the user is not an admin, deny login.
      if (!_appActive && user.role != UserRole.admin) {
        setState(() {
          _error =
              'Nur Administratoren können sich anmelden, wenn die App deaktiviert ist.';
        });
        return;
      }
      widget.onLogin(user);
    } catch (_) {
      setState(() => _error = 'Ungültiger Benutzername oder Passwort');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmeldung'),
      ),
      body: _loadingSettings
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_appActive && !_showLoginFields) ...[
                      const Text(
                        'Derzeit findet kein Spiel statt und die App ist deaktiviert.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showLoginFields = true;
                          });
                        },
                        child: const Text('Admin Login'),
                      ),
                    ] else ...[
                      if (_appActive && _gameInfo != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _gameInfo!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(labelText: 'Benutzername'),
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _attemptLogin(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _passwordController,
                        decoration: const InputDecoration(labelText: 'Passwort'),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _attemptLogin(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _attemptLogin,
                        child: const Text('Anmelden'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}