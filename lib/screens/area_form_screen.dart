import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_area.dart';
import '../models/user.dart';

/// A form for creating a new area or editing an existing one.
///
/// An area is defined by a polygon drawn on each of the three stadium
/// plans. The user taps on each plan to add vertices; at least three
/// vertices are required per plan. The area also has a name, a colour
/// and a list of assigned users (ordner) who are responsible for
/// monitoring it. When saved, the area is stored in persistent
/// storage under the key `areas_all`.
class AreaFormScreen extends StatefulWidget {
  final List<User> users;
  final StadiumArea? existingArea;

  const AreaFormScreen({Key? key, required this.users, this.existingArea})
      : super(key: key);

  @override
  State<AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<AreaFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final List<List<Offset?>> _positions;
  late int _colorValue;
  late List<String> _assignedUsers;
  late final TabController _tabController;

  final List<String> _mapAssets = const [
    'assets/stadion1.png',
    'assets/stadion2.png',
    'assets/stadion3.png',
  ];
  final List<Size> _imageSizes = const [
    Size(958, 657),
    Size(987, 672),
    Size(1018, 803),
  ];

  // Define a set of selectable colours for areas. Each colour is paired
  // with a human‑readable name. The colour value is stored in
  // persistent storage.
  final List<MapEntry<Color, String>> _colourOptions = const [
    MapEntry(Colors.red, 'Rot'),
    MapEntry(Colors.green, 'Grün'),
    MapEntry(Colors.blue, 'Blau'),
    MapEntry(Colors.orange, 'Orange'),
    MapEntry(Colors.purple, 'Lila'),
    MapEntry(Colors.teal, 'Türkis'),
  ];

  List<User> get _ordnerUsers =>
      widget.users.where((u) => u.role == UserRole.ordner).toList();

  bool get _isEditing => widget.existingArea != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _mapAssets.length, vsync: this);
    if (_isEditing) {
      final area = widget.existingArea!;
      _nameController = TextEditingController(text: area.name);
      _positions = List<List<Offset?>>.generate(
        _mapAssets.length,
        (i) => area.positions.length > i
            ? area.positions[i].map((o) => o).toList()
            : <Offset?>[],
      );
      _colorValue = area.colorValue;
      _assignedUsers = List<String>.from(area.assignedUsers);
    } else {
      _nameController = TextEditingController();
      _positions = List<List<Offset?>>.generate(
        _mapAssets.length,
        (i) => <Offset?>[],
      );
      _colorValue = _colourOptions.first.key.value;
      _assignedUsers = [];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveArea() async {
    if (!_formKey.currentState!.validate()) return;
    // Ensure each map has at least 3 vertices
    for (final list in _positions) {
      if (list.length < 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Für jeden Plan müssen mindestens drei Punkte gesetzt werden.')),
        );
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('areas_all');
    List<dynamic> listJson;
    if (jsonString != null && jsonString.isNotEmpty) {
      listJson = jsonDecode(jsonString) as List<dynamic>;
    } else {
      listJson = [];
    }
    List<StadiumArea> areas = listJson
        .map((e) => StadiumArea.fromJson(e as Map<String, dynamic>))
        .toList();
    if (_isEditing) {
      // Update existing
      final id = widget.existingArea!.id;
      final idx = areas.indexWhere((a) => a.id == id);
      if (idx != -1) {
        areas[idx] = areas[idx].copyWith(
          name: _nameController.text.trim(),
          positions: _positions
              .map((list) => list.map((o) => o!).toList())
              .toList(),
          colorValue: _colorValue,
          assignedUsers: List<String>.from(_assignedUsers),
        );
      }
    } else {
      // Create new
      final newArea = StadiumArea(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        positions: _positions
            .map((list) => list.map((o) => o!).toList())
            .toList(),
        colorValue: _colorValue,
        assignedUsers: List<String>.from(_assignedUsers),
      );
      areas.add(newArea);
    }
    final data = areas.map((a) => a.toJson()).toList();
    await prefs.setString('areas_all', jsonEncode(data));
    Navigator.of(context).pop(true);
  }

  Future<void> _deleteArea() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bereich löschen?'),
        content: Text('Möchten Sie den Bereich "${widget.existingArea!.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('areas_all');
    if (jsonString == null || jsonString.isEmpty) {
      Navigator.of(context).pop(true);
      return;
    }
    final listJson = jsonDecode(jsonString) as List<dynamic>;
    List<StadiumArea> areas = listJson
        .map((e) => StadiumArea.fromJson(e as Map<String, dynamic>))
        .toList();
    areas.removeWhere((a) => a.id == widget.existingArea!.id);
    final data = areas.map((a) => a.toJson()).toList();
    await prefs.setString('areas_all', jsonEncode(data));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Bereich bearbeiten' : 'Bereich erstellen'),
      ),
      body: Column(
        children: [
          // Tab bar for selecting which plan to place vertices on.
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            tabs: List.generate(_mapAssets.length,
                (i) => Tab(text: 'Plan ${i + 1}')),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(_mapAssets.length, (index) => _buildMapTab(index)),
            ),
          ),
          // Form fields for area name, colour and user assignment.
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Bereichsname',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Bitte geben Sie einen Namen ein';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  // Colour selection dropdown
                  DropdownButtonFormField<int>(
                    value: _colorValue,
                    decoration: const InputDecoration(
                      labelText: 'Farbe',
                      border: OutlineInputBorder(),
                    ),
                    items: _colourOptions.map((entry) {
                      return DropdownMenuItem<int>(
                        value: entry.key.value,
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              color: entry.key,
                            ),
                            const SizedBox(width: 8),
                            Text(entry.value),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _colorValue = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // User assignment checkboxes
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ordner zuweisen',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  ..._ordnerUsers.map((u) {
                    final selected = _assignedUsers.contains(u.username);
                    return CheckboxListTile(
                      title: Text(u.username),
                      value: selected,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            if (!_assignedUsers.contains(u.username)) {
                              _assignedUsers.add(u.username);
                            }
                          } else {
                            _assignedUsers.remove(u.username);
                          }
                        });
                      },
                    );
                  }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_isEditing)
                        ElevatedButton.icon(
                          onPressed: _deleteArea,
                          icon: const Icon(Icons.delete),
                          label: const Text('Löschen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ElevatedButton.icon(
                        onPressed: _saveArea,
                        icon: const Icon(Icons.save),
                        label: const Text('Speichern'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the interactive map for the given tab index. Users can tap
  /// inside the image to add vertices. A small marker is shown at each
  /// vertex. An "Letzten Punkt entfernen" button allows removing the
  /// most recently added vertex on that plan.
  Widget _buildMapTab(int index) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final originalW = _imageSizes[index].width;
        final originalH = _imageSizes[index].height;
        final scale = [width / originalW, height / originalH, 1.0]
            .reduce((a, b) => a < b ? a : b);
        final imageW = originalW * scale;
        final imageH = originalH * scale;
        final offX = (width - imageW) / 2;
        final offY = (height - imageH) / 2;
        return Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.white)),
            Positioned(
              left: offX,
              top: offY,
              width: imageW,
              height: imageH,
              child: Image.asset(_mapAssets[index], fit: BoxFit.fill),
            ),
            // Gesture detector for adding vertices
            Positioned.fill(
              child: GestureDetector(
                onTapUp: (d) {
                  final local = d.localPosition;
                  if (local.dx >= offX &&
                      local.dx <= offX + imageW &&
                      local.dy >= offY &&
                      local.dy <= offY + imageH) {
                    final relX = (local.dx - offX) / imageW;
                    final relY = (local.dy - offY) / imageH;
                    setState(() {
                      _positions[index].add(Offset(relX, relY));
                    });
                  }
                },
              ),
            ),
            // Draw each vertex as a small coloured square
            ..._positions[index].asMap().entries.map((entry) {
              final idx = entry.key;
              final pos = entry.value;
              if (pos == null) return const SizedBox.shrink();
              final cx = offX + pos.dx * imageW;
              final cy = offY + pos.dy * imageH;
              return Positioned(
                left: cx - 4,
                top: cy - 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Color(_colorValue),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
            // Undo button to remove the last vertex on this map
            Positioned(
              right: 8,
              bottom: 8,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (_positions[index].isNotEmpty) {
                      _positions[index].removeLast();
                    }
                  });
                },
                child: const Text('Letzten Punkt entfernen'),
              ),
            ),
          ],
        );
      },
    );
  }
}