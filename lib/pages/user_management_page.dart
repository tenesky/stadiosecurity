import 'package:flutter/material.dart';
import '../services/db_service.dart';

/// A page that allows administrators to manage users (Mitarbeiter / Benutzer).
/// Users can be created, edited, and have their passwords reset.  Roles
/// can also be assigned.
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final users = await DbService.getUsersWithRoles();
    final roles = await DbService.getRoles();
    setState(() {
      _users = users;
      _roles = roles;
      _loading = false;
    });
  }

  void _showUserDialog({Map<String, dynamic>? user}) {
    final bool isEditing = user != null;
    final _usernameController = TextEditingController(text: user?['username'] as String? ?? '');
    final _passwordController = TextEditingController();
    int? selectedRoleId = user != null ? user['role_id'] as int? : (_roles.isNotEmpty ? _roles.first['id'] as int : null);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Benutzer bearbeiten' : 'Benutzer erstellen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Benutzername'),
                ),
                const SizedBox(height: 8),
                // Only ask for password when creating a new user
                if (!isEditing)
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Passwort'),
                    obscureText: true,
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  // Use initialValue instead of the deprecated value parameter.
                  initialValue: selectedRoleId,
                  decoration: const InputDecoration(labelText: 'Rolle'),
                  items: _roles
                      .map(
                        (role) => DropdownMenuItem<int>(
                          value: role['id'] as int,
                          child: Text(role['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    selectedRoleId = value;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final username = _usernameController.text.trim();
                if (username.isEmpty) return;
                if (isEditing) {
                  // The 'user' argument is non-null when editing, so we can
                  // safely access its properties without a null‑assertion.
                  await DbService.updateUser(
                    userId: user['id'] as int,
                    username: username,
                    roleId: selectedRoleId,
                  );
                } else {
                  final password = _passwordController.text;
                  if (password.isEmpty) return;
                  await DbService.createUser(
                    username: username,
                    password: password,
                    roleId: selectedRoleId ?? 0,
                  );
                }
                if (mounted) {
                  Navigator.of(context).pop();
                  await _loadData();
                }
              },
              child: Text(isEditing ? 'Speichern' : 'Erstellen'),
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final _pwController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Passwort zurücksetzen für ${user['username']}'),
          content: TextField(
            controller: _pwController,
            decoration: const InputDecoration(labelText: 'Neues Passwort'),
            obscureText: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPw = _pwController.text;
                if (newPw.isEmpty) return;
                await DbService.updatePassword(userId: user['id'] as int, newPassword: newPw);
                if (mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Zurücksetzen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Benutzerverwaltung')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(child: Text('Keine Benutzer gefunden'))
              : ListView.separated(
                  itemCount: _users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    return ListTile(
                      title: Text(user['username'] as String),
                      subtitle: Text(
                        user['role_name'] != null
                            ? 'Rolle: ${user['role_name']}'
                            : 'Keine Rolle',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showUserDialog(user: user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.lock_reset),
                            onPressed: () => _showResetPasswordDialog(user),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Benutzer löschen'),
                                  content: Text(
                                      'Möchtest du den Benutzer ${user['username']} wirklich löschen?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Abbrechen'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Löschen'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await DbService.deleteUser(user['id'] as int);
                                await _loadData();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showUserDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}