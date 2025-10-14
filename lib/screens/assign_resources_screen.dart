import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_point.dart';
import '../models/stadium_area.dart';
import '../models/user.dart';

/// A page that allows assigning both stadium points and areas to a
/// specific Ordner. This screen lists all existing points and areas
/// with a checkbox next to each. When the user toggles a checkbox,
/// the corresponding point or area will be assigned to or removed
/// from the selected user when saved.
class AssignResourcesScreen extends StatefulWidget {
  final User user;

  const AssignResourcesScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<AssignResourcesScreen> createState() => _AssignResourcesScreenState();
}

class _AssignResourcesScreenState extends State<AssignResourcesScreen> {
  List<StadiumPoint> _points = [];
  List<StadiumArea> _areas = [];
  final Map<String, bool> _selectedPoints = {};
  final Map<String, bool> _selectedAreas = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  /// Loads all points and areas from persistent storage and sets
  /// up the initial selection state based on the current user's
  /// assignments.
  Future<void> _loadResources() async {
    final prefs = await SharedPreferences.getInstance();
    final pointsString = prefs.getString('points_all');
    final areasString = prefs.getString('areas_all');
    _points.clear();
    _areas.clear();
    if (pointsString != null && pointsString.isNotEmpty) {
      final decoded = jsonDecode(pointsString) as List<dynamic>;
      for (final e in decoded) {
        final point = StadiumPoint.fromJson(e as Map<String, dynamic>);
        _points.add(point);
        _selectedPoints[point.id] = point.assignedUsers.contains(widget.user.username);
      }
    }
    if (areasString != null && areasString.isNotEmpty) {
      final decoded = jsonDecode(areasString) as List<dynamic>;
      for (final e in decoded) {
        final area = StadiumArea.fromJson(e as Map<String, dynamic>);
        _areas.add(area);
        _selectedAreas[area.id] = area.assignedUsers.contains(widget.user.username);
      }
    }
    setState(() {
      _loading = false;
    });
  }

  /// Persists the updated assignments back to persistent storage.
  /// For each point and area, the assignedUsers list is modified
  /// according to the selected state. The updated lists are saved
  /// under the keys `points_all` and `areas_all`.
  Future<void> _saveAssignments() async {
    final updatedPoints = _points.map((p) {
      final bool selected = _selectedPoints[p.id] ?? false;
      final List<String> users = List<String>.from(p.assignedUsers);
      if (selected) {
        if (!users.contains(widget.user.username)) {
          users.add(widget.user.username);
        }
      } else {
        users.remove(widget.user.username);
      }
      return p.copyWith(assignedUsers: users);
    }).toList();
    final updatedAreas = _areas.map((a) {
      final bool selected = _selectedAreas[a.id] ?? false;
      final List<String> users = List<String>.from(a.assignedUsers);
      if (selected) {
        if (!users.contains(widget.user.username)) {
          users.add(widget.user.username);
        }
      } else {
        users.remove(widget.user.username);
      }
      return a.copyWith(assignedUsers: users);
    }).toList();
    _points = updatedPoints;
    _areas = updatedAreas;
    final prefs = await SharedPreferences.getInstance();
    final pointsData = updatedPoints.map((p) => p.toJson()).toList();
    final areasData = updatedAreas.map((a) => a.toJson()).toList();
    await prefs.setString('points_all', jsonEncode(pointsData));
    await prefs.setString('areas_all', jsonEncode(areasData));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zuweisung für ${widget.user.username}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Points section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Punkte',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ..._points.map((p) {
                    final selected = _selectedPoints[p.id] ?? false;
                    return CheckboxListTile(
                      title: Text('${p.name} (${p.type.displayName})'),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          _selectedPoints[p.id] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                  // Areas section
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Bereiche',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ..._areas.map((a) {
                    final selected = _selectedAreas[a.id] ?? false;
                    return CheckboxListTile(
                      title: Text(a.name),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          _selectedAreas[a.id] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
      floatingActionButton: _loading
          ? null
          : FloatingActionButton(
              onPressed: () async {
                await _saveAssignments();
                Navigator.of(context).pop(true);
              },
              child: const Icon(Icons.save),
            ),
    );
  }
}