import 'package:flutter/material.dart';
import '../models/user.dart';
import 'stadium_screen.dart';
// The points list screen is no longer used because points and areas are
// combined in a single overview (ResourcesListScreen).
import 'area_form_screen.dart';
import 'resources_list_screen.dart';
import 'settings_screen.dart';
import 'user_management_screen.dart';
import 'point_form_screen.dart';

/// Home screen shown after successful login. Displays the current user and
/// provides navigation options based on their role: stadium view,
/// list view and user management (for admins and Einsatzleiter). Also
/// allows users to log out.
class HomeScreen extends StatelessWidget {
  final User currentUser;
  final VoidCallback onLogout;
  final List<User> users;
  final void Function(User) onDeleteUser;
  final void Function(User) onAddUser;

  const HomeScreen({
    Key? key,
    required this.currentUser,
    required this.onLogout,
    required this.users,
    required this.onDeleteUser,
    required this.onAddUser,
  }) : super(key: key);

  bool get _canManageUsers =>
      currentUser.role == UserRole.admin || currentUser.role == UserRole.einsatzleiter;

  /// Whether the current user is allowed to create or edit points. Only
  /// admins and Einsatzleiter may create new points or modify existing
  /// ones.
  bool get _canCreatePoint =>
      currentUser.role == UserRole.admin || currentUser.role == UserRole.einsatzleiter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Willkommen, ${currentUser.username}'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Rolle: ${currentUser.role.displayName}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StadiumScreen(
                      currentUser: currentUser,
                      users: users,
                    ),
                  ),
                );
              },
              child: const Text('Stadionansicht'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ResourcesListScreen(
                      currentUser: currentUser,
                      users: users,
                    ),
                  ),
                );
              },
              child: const Text('Listenansicht'),
            ),

            // Button to create a new point. Only visible for admins and
            // Einsatzleiter.
            if (_canCreatePoint) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PointFormScreen(
                        // Only the list of users is required when creating a new point.
                        users: users,
                      ),
                    ),
                  );
                },
                child: const Text('Punkt erstellen'),
              ),

              // Button to create a new area. This option is available only
              // to admins and Einsatzleiter. It opens the AreaFormScreen
              // where the user can define an area across all plans.
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AreaFormScreen(
                        users: users,
                      ),
                    ),
                  );
                },
                child: const Text('Bereich erstellen'),
              ),
              // Button to open the settings page. Only admins may change
              // global app settings such as match information and app
              // activation state.
              if (currentUser.role == UserRole.admin) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ),
                    );
                  },
                  child: const Text('Einstellungen'),
                ),
              ],
            ],
            if (_canManageUsers) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => UserManagementScreen(
                        users: users,
                        onDeleteUser: onDeleteUser,
                        onAddUser: onAddUser,
                      ),
                    ),
                  );
                },
                child: const Text('Benutzerverwaltung'),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: onLogout,
              child: const Text('Abmelden'),
            ),
          ],
        ),
      ),
    );
  }
}