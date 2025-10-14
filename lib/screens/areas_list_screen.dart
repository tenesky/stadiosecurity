import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_area.dart';
import '../models/user.dart';
import 'area_form_screen.dart';

/// A screen that lists all existing areas in the system with a
/// search/filter function. Admins and Einsatzleiter can edit or
/// delete areas directly from this overview. Ordners and
/// Bereichsleiter can only view the list. The screen returns
/// `true` when any modifications have been made so that callers can
/// reload their data.
class AreasListScreen extends StatefulWidget {
  /// The current logged‑in user. Determines which actions are allowed.
  final User currentUser;

  /// List of all users. Required for assigning ordners when editing.
  final List<User> users;

  const AreasListScreen({Key? key, required this.currentUser, required this.users})
      : super(key: key);

  @override
  State<AreasListScreen> createState() => _AreasListScreenState();
}

class _AreasListScreenState extends State<AreasListScreen> {
  final List<StadiumArea> _areas = [];
  bool _modified = false;
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _canEdit => widget.currentUser.role == UserRole.admin ||
      widget.currentUser.role == UserRole.einsatzleiter;

  @override
  void initState() {
    super.initState();
    _loadAreas();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Loads the list of areas from persistent storage. Areas are stored
  /// under the key `areas_all` and contain vertices for each plan.
  Future<void> _loadAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('areas_all');
    _areas.clear();
    if (jsonString != null && jsonString.isNotEmpty) {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      for (final e in decoded) {
        final area = StadiumArea.fromJson(e as Map<String, dynamic>);
        _areas.add(area);
      }
    }
    setState(() {
      _loading = false;
    });
  }

  /// Saves the current list of areas back to persistent storage.
  Future<void> _saveAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _areas.map((a) => a.toJson()).toList();
    await prefs.setString('areas_all', jsonEncode(data));
  }

  /// Prompts the user for confirmation before deleting an area. If
  /// confirmed, removes the area from the list and persists the change.
  Future<void> _deleteArea(StadiumArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bereich löschen?'),
        content: Text(
            'Möchten Sie den Bereich "${area.name}" wirklich unwiderruflich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      setState(() {
        _areas.removeWhere((a) => a.id == area.id);
        _modified = true;
      });
      await _saveAreas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(title: const Text('Alle Bereiche')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Suchen...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase().trim();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: _areas.isEmpty
                        ? const Center(child: Text('Keine Bereiche vorhanden'))
                        : ListView.builder(
                            itemCount: _areas.length,
                            itemBuilder: (context, index) {
                              final area = _areas[index];
                              // Apply search filter: match name or assigned user
                              if (_searchQuery.isNotEmpty &&
                                  !(area.name.toLowerCase().contains(_searchQuery) ||
                                    area.assignedUsers.any((u) => u.toLowerCase().contains(_searchQuery)))) {
                                return const SizedBox.shrink();
                              }
                              return ListTile(
                                leading: Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: area.isReady ? Colors.greenAccent : Colors.redAccent,
                                  ),
                                ),
                                title: Text(area.name),
                                subtitle: Text('Zugewiesen: ${area.assignedUsers.join(', ')}'),
                                trailing: _canEdit
                                    ? Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            onPressed: () async {
                                              final updated = await Navigator.of(context).push<bool>(
                                                MaterialPageRoute(
                                                  builder: (_) => AreaFormScreen(
                                                    users: widget.users,
                                                    existingArea: area,
                                                  ),
                                                ),
                                              );
                                              if (updated == true) {
                                                _modified = true;
                                                await _loadAreas();
                                              }
                                            },
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.red),
                                            onPressed: () => _deleteArea(area),
                                          ),
                                        ],
                                      )
                                    : null,
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Intercepts the back navigation to return whether modifications were
  /// made while this screen was open.
  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_modified);
    return false;
  }
}