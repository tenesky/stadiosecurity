import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_point.dart';
import '../models/user.dart';
import 'point_form_screen.dart';

/// A screen that lists all existing points in the system.
///
/// Admins and Einsatzleiter can edit or delete points directly from this
/// overview. Ordners and Bereichsleiter can only view the list. When a
/// point is edited or deleted, the changes are saved back to persistent
/// storage and the list refreshes. The screen returns `true` when any
/// modifications have been made so that callers can reload their data.
class PointsListScreen extends StatefulWidget {
  /// The current logged‑in user. Determines which actions are allowed.
  final User currentUser;

  /// List of all users. Required for assigning ordners when editing.
  final List<User> users;

  const PointsListScreen({Key? key, required this.currentUser, required this.users})
      : super(key: key);

  @override
  State<PointsListScreen> createState() => _PointsListScreenState();
}

class _PointsListScreenState extends State<PointsListScreen> {
  final List<StadiumPoint> _points = [];
  bool _modified = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _canEdit => widget.currentUser.role == UserRole.admin ||
      widget.currentUser.role == UserRole.einsatzleiter;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  /// Loads the list of points from persistent storage. Points are stored
  /// under the key `points_all` and contain a list of positions for
  /// each stadium plan. Assigned users are also loaded.
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('points_all');
    _points.clear();
    if (jsonString != null && jsonString.isNotEmpty) {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      for (final e in decoded) {
        final positions = (e['positions'] as List<dynamic>).map((p) {
          return Offset(
            (p['dx'] as num).toDouble(),
            (p['dy'] as num).toDouble(),
          );
        }).toList();
        final assigned = (e['assignedUsers'] as List<dynamic>?)
                ?.map((u) => u as String)
                .toList() ??
            [];
        final point = StadiumPoint(
          id: e['id'] as String,
          name: e['name'] as String,
          type: StadiumPointType.values.firstWhere((t) => t.name == e['type']),
          positions: positions,
          isReady: e['isReady'] as bool? ?? false,
          assignedUsers: assigned,
        );
        _points.add(point);
      }
    }
    setState(() {});
  }

  /// Saves the current list of points back to persistent storage.
  Future<void> _savePoints() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _points.map((p) {
      return {
        'id': p.id,
        'name': p.name,
        'type': p.type.name,
        'positions': p.positions
            .map((pos) => {'dx': pos.dx, 'dy': pos.dy})
            .toList(),
        'isReady': p.isReady,
        'assignedUsers': p.assignedUsers,
      };
    }).toList();
    await prefs.setString('points_all', jsonEncode(data));
  }

  /// Prompts the user for confirmation before deleting a point. If
  /// confirmed, removes the point from the list and persists the change.
  Future<void> _deletePoint(StadiumPoint point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Punkt löschen?'),
        content: Text(
            'Möchten Sie den Punkt "${point.name}" wirklich unwiderruflich löschen?'),
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
        _points.removeWhere((p) => p.id == point.id);
        _modified = true;
      });
      await _savePoints();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(title: const Text('Alle Punkte')),
        body: _points.isEmpty
            ? const Center(child: Text('Keine Punkte vorhanden'))
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
                    child: ListView.builder(
                      itemCount: _points.length,
                      itemBuilder: (context, index) {
                        final p = _points[index];
                        // Apply search filter: match name, type or assigned users
                        if (_searchQuery.isNotEmpty &&
                            !(p.name.toLowerCase().contains(_searchQuery) ||
                              p.type.displayName.toLowerCase().contains(_searchQuery) ||
                              p.assignedUsers.any((u) => u.toLowerCase().contains(_searchQuery)))) {
                          return const SizedBox.shrink();
                        }
                        return ListTile(
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.isReady
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                            ),
                          ),
                          title: Text(p.name),
                          subtitle: Text(p.type.displayName),
                          trailing: _canEdit
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () async {
                                        final updated = await Navigator.of(context)
                                            .push<bool>(
                                          MaterialPageRoute(
                                            builder: (_) => PointFormScreen(
                                              users: widget.users,
                                              existingPoint: p,
                                            ),
                                          ),
                                        );
                                        if (updated == true) {
                                          _modified = true;
                                          _loadPoints();
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deletePoint(p),
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Intercepts the back navigation (e.g. via system back button) to
  /// return whether modifications were made while this screen was open.
  Future<bool> _onWillPop() async {
    Navigator.of(context).pop(_modified);
    return false;
  }
}