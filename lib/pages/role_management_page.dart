import 'package:flutter/material.dart';
import '../services/db_service.dart';

/// A page to manage roles.  Administrators can create, edit and delete
/// roles.  Note: deleting a role may require reassigning users first.
class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _roles = [];

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _loading = true);
    final roles = await DbService.getRoles();
    setState(() {
      _roles = roles;
      _loading = false;
    });
  }

  void _showRoleDialog({Map<String, dynamic>? role}) {
    final bool isEditing = role != null;
    final _nameController = TextEditingController(text: role?['name'] as String? ?? '');
    final _descriptionController = TextEditingController(text: role?['description'] as String? ?? '');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEditing ? 'Rolle bearbeiten' : 'Rolle erstellen'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Beschreibung'),
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
                final name = _nameController.text.trim();
                final description = _descriptionController.text.trim().isEmpty
                    ? null
                    : _descriptionController.text.trim();
                if (name.isEmpty) return;
                if (isEditing) {
                  await DbService.updateRole(
                    roleId: role['id'] as int,
                    name: name,
                    description: description,
                  );
                } else {
                  await DbService.createRole(name: name, description: description);
                }
                if (mounted) {
                  Navigator.of(context).pop();
                  await _loadRoles();
                }
              },
              child: Text(isEditing ? 'Speichern' : 'Erstellen'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rollenverwaltung')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _roles.isEmpty
              ? const Center(child: Text('Keine Rollen vorhanden'))
              : ListView.separated(
                  itemCount: _roles.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final role = _roles[index];
                    return ListTile(
                      title: Text(role['name'] as String),
                      subtitle: role['description'] != null && (role['description'] as String).isNotEmpty
                          ? Text(role['description'] as String)
                          : const Text(''),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showRoleDialog(role: role),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Rolle löschen'),
                                  content: Text(
                                      'Möchtest du die Rolle ${role['name']} wirklich löschen?\nHinweis: Benutzer mit dieser Rolle verlieren ihre Zuordnung.'),
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
                                await DbService.deleteRole(role['id'] as int);
                                await _loadRoles();
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRoleDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}