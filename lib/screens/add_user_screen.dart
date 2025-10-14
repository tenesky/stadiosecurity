import 'package:flutter/material.dart';
import '../models/user.dart';

/// A form allowing privileged users to add a new user to the system.
/// Validates that the username is unique and that both fields are non‑empty.
class AddUserScreen extends StatefulWidget {
  final List<User> existingUsers;
  final void Function(User) onAddUser;

  const AddUserScreen({
    Key? key,
    required this.existingUsers,
    required this.onAddUser,
  }) : super(key: key);

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  UserRole _role = UserRole.ordner;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();
      if (widget.existingUsers.any((u) => u.username == username)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Benutzername bereits vergeben')),
        );
        return;
      }
      final user = User(username: username, password: password, role: _role);
      widget.onAddUser(user);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Benutzer hinzufügen')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'Benutzername',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Benutzername erforderlich';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Passwort',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Passwort erforderlich';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                value: _role,
                decoration: const InputDecoration(
                  labelText: 'Rolle',
                  border: OutlineInputBorder(),
                ),
                items: UserRole.values.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _role = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Speichern'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}