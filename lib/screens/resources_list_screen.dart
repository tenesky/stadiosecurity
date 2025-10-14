import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_point.dart';
import '../models/stadium_area.dart';
import '../models/user.dart';
import 'point_form_screen.dart';
import 'area_form_screen.dart';

/// Combined list view for both stadium points and areas. This screen
/// presents all points and areas in a single searchable list, allowing
/// authorised users (Admins and Einsatzleiter) to edit or delete
/// entries. Searching matches against the resource name, point type and
/// assigned users. When modifications occur the screen returns `true`
/// to the caller so that underlying data can be reloaded.
class ResourcesListScreen extends StatefulWidget {
  final User currentUser;
  final List<User> users;

  const ResourcesListScreen({Key? key, required this.currentUser, required this.users})
      : super(key: key);

  @override
  State<ResourcesListScreen> createState() => _ResourcesListScreenState();
}

class _ResourcesListScreenState extends State<ResourcesListScreen> {
  List<StadiumPoint> _points = [];
  List<StadiumArea> _areas = [];
  bool _modified = false;
  bool _loading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  bool get _canEdit => widget.currentUser.role == UserRole.admin ||
      widget.currentUser.role == UserRole.einsatzleiter;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Loads points and areas from `SharedPreferences`.
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final pointsString = prefs.getString('points_all');
    final areasString = prefs.getString('areas_all');
    _points = [];
    _areas = [];
    if (pointsString != null && pointsString.isNotEmpty) {
      final decoded = jsonDecode(pointsString) as List<dynamic>;
      for (final dynamic e in decoded) {
        final point = StadiumPoint.fromJson(e as Map<String, dynamic>);
        _points.add(point);
      }
    }
    if (areasString != null && areasString.isNotEmpty) {
      final decoded = jsonDecode(areasString) as List<dynamic>;
      for (final dynamic e in decoded) {
        final area = StadiumArea.fromJson(e as Map<String, dynamic>);
        _areas.add(area);
      }
    }
    setState(() {
      _loading = false;
    });
  }

  /// Saves all points back to persistent storage.
  Future<void> _savePoints() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _points.map((p) => p.toJson()).toList();
    await prefs.setString('points_all', jsonEncode(data));
  }

  /// Saves all areas back to persistent storage.
  Future<void> _saveAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _areas.map((a) => a.toJson()).toList();
    await prefs.setString('areas_all', jsonEncode(data));
  }

  /// Prompts for confirmation then deletes the provided point.
  Future<void> _deletePoint(StadiumPoint point) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Punkt löschen?'),
        content: Text('Möchten Sie den Punkt "${point.name}" wirklich unwiderruflich löschen?'),
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

  /// Prompts for confirmation then deletes the provided area.
  Future<void> _deleteArea(StadiumArea area) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bereich löschen?'),
        content: Text('Möchten Sie den Bereich "${area.name}" wirklich unwiderruflich löschen?'),
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_modified);
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Alle Punkte und Bereiche'),
        ),
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
                    child: (_points.isEmpty && _areas.isEmpty)
                        ? const Center(child: Text('Keine Punkte oder Bereiche vorhanden'))
                        : ListView.builder(
                            itemCount: _points.length + _areas.length,
                            itemBuilder: (context, index) {
                              // Determine if this index refers to a point or an area.
                              final bool isPoint = index < _points.length;
                              if (isPoint) {
                                final StadiumPoint p = _points[index];
                                // Apply search filter
                                final bool matches = _searchQuery.isEmpty ||
                                    p.name.toLowerCase().contains(_searchQuery) ||
                                    p.type.displayName.toLowerCase().contains(_searchQuery) ||
                                    p.assignedUsers.any((u) => u.toLowerCase().contains(_searchQuery));
                                if (!matches) {
                                  return const SizedBox.shrink();
                                }
                                return ListTile(
                                  leading: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: p.isReady ? Colors.greenAccent : Colors.redAccent,
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
                                                final changed = await Navigator.of(context).push<bool>(
                                                  MaterialPageRoute(
                                                    builder: (_) => PointFormScreen(
                                                      users: widget.users,
                                                      existingPoint: p,
                                                    ),
                                                  ),
                                                );
                                                if (changed == true) {
                                                  _modified = true;
                                                  await _loadData();
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
                              } else {
                                final int areaIndex = index - _points.length;
                                final StadiumArea a = _areas[areaIndex];
                                final bool matches = _searchQuery.isEmpty ||
                                    a.name.toLowerCase().contains(_searchQuery) ||
                                    a.assignedUsers.any((u) => u.toLowerCase().contains(_searchQuery));
                                if (!matches) {
                                  return const SizedBox.shrink();
                                }
                                return ListTile(
                                  leading: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: a.isReady ? Colors.greenAccent : Colors.redAccent,
                                    ),
                                  ),
                                  title: Text(a.name),
                                  subtitle: Text('Zugewiesen: ${a.assignedUsers.join(', ')}'),
                                  trailing: _canEdit
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.edit),
                                              onPressed: () async {
                                                final changed = await Navigator.of(context).push<bool>(
                                                  MaterialPageRoute(
                                                    builder: (_) => AreaFormScreen(
                                                      users: widget.users,
                                                      existingArea: a,
                                                    ),
                                                  ),
                                                );
                                                if (changed == true) {
                                                  _modified = true;
                                                  await _loadData();
                                                }
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.delete, color: Colors.red),
                                              onPressed: () => _deleteArea(a),
                                            ),
                                          ],
                                        )
                                      : null,
                                );
                              }
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}