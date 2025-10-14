import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A settings screen that allows administrators to configure the app's
/// state and match information. Admins can toggle whether the app is
/// currently active (i.e. a match is in progress) and specify details
/// about the upcoming game such as season, guest team, competition and
/// date/time. All settings are persisted via `SharedPreferences` so
/// that they are retained across restarts.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _appActive = true;
  final TextEditingController _seasonController = TextEditingController();
  final TextEditingController _guestTeamController = TextEditingController();
  String _competition = 'Regionalliga Nordost';
  DateTime? _gameDate;
  TimeOfDay? _gameTime;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  /// Loads existing settings from persistent storage. If no settings
  /// are found the app defaults to active with the current season.
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appActive = prefs.getBool('app_active') ?? true;
      _seasonController.text = prefs.getString('season') ?? '2025/26';
      _guestTeamController.text = prefs.getString('guest_team') ?? '';
      _competition = prefs.getString('competition') ?? 'Regionalliga Nordost';
      final String? dateStr = prefs.getString('game_date');
      if (dateStr != null) {
        final parsed = DateTime.tryParse(dateStr);
        if (parsed != null) {
          _gameDate = parsed;
        }
      }
      final String? timeStr = prefs.getString('game_time');
      if (timeStr != null) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final int? hour = int.tryParse(parts[0]);
          final int? minute = int.tryParse(parts[1]);
          if (hour != null && minute != null) {
            _gameTime = TimeOfDay(hour: hour, minute: minute);
          }
        }
      }
      _loading = false;
    });
  }

  /// Persists the current settings back to `SharedPreferences`. A
  /// confirmation message is displayed upon completion.
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_active', _appActive);
    await prefs.setString('season', _seasonController.text.trim());
    await prefs.setString('guest_team', _guestTeamController.text.trim());
    await prefs.setString('competition', _competition);
    if (_gameDate != null) {
      await prefs.setString('game_date', _gameDate!.toIso8601String());
    } else {
      await prefs.remove('game_date');
    }
    if (_gameTime != null) {
      final String formattedTime =
          '${_gameTime!.hour.toString().padLeft(2, '0')}:${_gameTime!.minute.toString().padLeft(2, '0')}';
      await prefs.setString('game_time', formattedTime);
    } else {
      await prefs.remove('game_time');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
    }
  }

  /// Opens a date picker to select the game date. The selected date
  /// replaces any existing date when the user confirms their choice.
  Future<void> _pickDate() async {
    final DateTime now = DateTime.now();
    final DateTime initialDate = _gameDate ?? now;
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date != null) {
      setState(() {
        _gameDate = date;
      });
    }
  }

  /// Opens a time picker to select the game time. The selected time
  /// replaces any existing time when the user confirms their choice.
  Future<void> _pickTime() async {
    final TimeOfDay initialTime = _gameTime ?? TimeOfDay.fromDateTime(DateTime.now());
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time != null) {
      setState(() {
        _gameTime = time;
      });
    }
  }

  @override
  void dispose() {
    _seasonController.dispose();
    _guestTeamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // Show a progress indicator while settings are loading.
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title: const Text('App aktiv'),
              value: _appActive,
              onChanged: (bool value) {
                setState(() {
                  _appActive = value;
                });
              },
            ),
            TextField(
              controller: _seasonController,
              decoration: const InputDecoration(
                labelText: 'Saison',
              ),
            ),
            // Display the fixed home team in a disabled text field.
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Heimverein',
              ),
              controller: TextEditingController(text: '1. FC Lokomotive Leipzig'),
              enabled: false,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _guestTeamController,
              decoration: const InputDecoration(
                labelText: 'Gastverein',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _competition,
              items: const [
                DropdownMenuItem(
                  value: 'Regionalliga Nordost',
                  child: Text('Regionalliga Nordost'),
                ),
                DropdownMenuItem(
                  value: 'Sachsenpokal',
                  child: Text('Sachsenpokal'),
                ),
              ],
              onChanged: (String? value) {
                if (value != null) {
                  setState(() {
                    _competition = value;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: 'Wettbewerb',
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _gameDate != null
                        ? 'Datum: ${_gameDate!.day.toString().padLeft(2, '0')}.${_gameDate!.month.toString().padLeft(2, '0')}.${_gameDate!.year}'
                        : 'Kein Datum gewählt',
                  ),
                ),
                TextButton(
                  onPressed: _pickDate,
                  child: const Text('Datum auswählen'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _gameTime != null
                        ? 'Uhrzeit: ${_gameTime!.format(context)}'
                        : 'Keine Uhrzeit gewählt',
                  ),
                ),
                TextButton(
                  onPressed: _pickTime,
                  child: const Text('Uhrzeit auswählen'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}