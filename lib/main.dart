import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/user.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

/// Entry point of the stadium administration app with user management.
void main() {
  runApp(const StadiumApp());
}

class StadiumApp extends StatefulWidget {
  const StadiumApp({Key? key}) : super(key: key);

  @override
  State<StadiumApp> createState() => _StadiumAppState();
}

class _StadiumAppState extends State<StadiumApp> {
  User? _currentUser;
  List<User> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('users');
    if (jsonString == null) {
      // Create default admin account on first launch
      _users = [
        User(username: 'admin', password: 'start#123', role: UserRole.admin),
      ];
      await prefs.setString(
        'users',
        jsonEncode(_users.map((u) => u.toJson()).toList()),
      );
    } else {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      _users = decoded.map((e) => User.fromJson(e)).toList();
    }
    setState(() {});
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'users',
      jsonEncode(_users.map((u) => u.toJson()).toList()),
    );
  }

  void _login(User user) {
    setState(() => _currentUser = user);
  }

  void _logout() {
    setState(() => _currentUser = null);
  }

  void _addUser(User user) {
    setState(() => _users.add(user));
    _saveUsers();
  }

  void _deleteUser(User user) {
    setState(() => _users.removeWhere((u) => u.username == user.username));
    _saveUsers();
    if (_currentUser != null && _currentUser!.username == user.username) {
      _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stadionverwaltung',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: _currentUser == null
          ? LoginScreen(
              users: _users,
              onLogin: _login,
            )
          : HomeScreen(
              currentUser: _currentUser!,
              onLogout: _logout,
              users: _users,
              onDeleteUser: _deleteUser,
              onAddUser: _addUser,
            ),
    );
  }
}