import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_point.dart';
import '../models/user.dart';

/// Screen allowing administrators or Einsatzleiter to assign points to an
/// Ordner user. All points (regardless of type) are loaded from
/// persistent storage and displayed with a checkbox indicating whether
/// the selected user is currently assigned. Changes are saved back
/// to `points_all` when the user taps the save button.
class AssignPointsScreen extends StatefulWidget {
  final User user;

  const AssignPointsScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<AssignPointsScreen> createState() => _AssignPointsScreenState();
}

class _AssignPointsScreenState extends State<AssignPointsScreen> {
  List<StadiumPoint> _points = [];
  final Map<String, bool> _selected = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  /// Loads all points from the `points_all` store. Only Ordner
  /// assignments are considered; multiple assignments are allowed.
  Future<void> _loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('points_all');
    _points = [];
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
    for (final p in _points) {
      _selected[p.id] = p.assignedUsers.contains(widget.user.username);
    }
    setState(() {
      _loading = false;
    });
  }

  /// Persists the updated assignments back to `points_all`. This
  /// iterates over all points, updating the `assignedUsers` list based
  /// on the current checkbox state.
  Future<void> _saveAssignments() async {
    final updated = _points.map((p) {
      final bool isSelected = _selected[p.id] ?? false;
      final List<String> users = List<String>.from(p.assignedUsers);
      if (isSelected) {
        if (!users.contains(widget.user.username)) {
          users.add(widget.user.username);
        }
      } else {
        users.remove(widget.user.username);
      }
      return p.copyWith(assignedUsers: users);
    }).toList();
    _points = updated;
    final prefs = await SharedPreferences.getInstance();
    final data = updated.map((p) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zuweisung für ${widget.user.username}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _points.isEmpty
              ? const Center(child: Text('Keine Punkte zum Zuweisen'))
              : ListView(
                  children: _points.map((p) {
                    final selected = _selected[p.id] ?? false;
                    return CheckboxListTile(
                      title: Text('${p.name} (${p.type.displayName})'),
                      value: selected,
                      onChanged: (bool? value) {
                        setState(() {
                          _selected[p.id] = value ?? false;
                        });
                      },
                    );
                  }).toList(),
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