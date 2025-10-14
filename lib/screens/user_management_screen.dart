import 'package:flutter/material.dart';
import '../models/user.dart';
import 'add_user_screen.dart';
import 'assign_resources_screen.dart';

/// Screen that lists all users and allows deletion and addition. Only
/// accessible to users with sufficient privileges (admin and Einsatzleiter).
class UserManagementScreen extends StatelessWidget {
  final List<User> users;
  final void Function(User) onDeleteUser;
  final void Function(User) onAddUser;

  const UserManagementScreen({
    Key? key,
    required this.users,
    required this.onDeleteUser,
    required this.onAddUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Benutzerverwaltung')),
      body: ListView.builder(
        itemCount: users.length,
        itemBuilder: (context, index) {
          final user = users[index];
          return ListTile(
            title: Text(user.username),
            subtitle: Text(user.role.displayName),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Assignment button only for Ordner role
                if (user.role == UserRole.ordner)
                  IconButton(
                    icon: const Icon(Icons.assignment, color: Colors.blue),
                    tooltip: 'Punkte zuweisen',
                    onPressed: () async {
                      // Navigate to assignment screen; if assignments changed,
                      // show a Snackbar on return.
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AssignResourcesScreen(user: user),
                        ),
                      );
                      if (changed == true) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Zuweisungen für ${user.username} wurden aktualisiert'),
                          ),
                        );
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Benutzer löschen',
                  onPressed: () {
                    if (user.username == 'admin') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Der Admin-Benutzer kann nicht gelöscht werden'),
                        ),
                      );
                      return;
                    }
                    onDeleteUser(user);
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddUserScreen(
                existingUsers: users,
                onAddUser: onAddUser,
              ),
            ),
          );
        },
        child: const Icon(Icons.person_add),
      ),
    );
  }
}