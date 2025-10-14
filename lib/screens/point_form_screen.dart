import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_point.dart';
import '../models/user.dart';

/// A screen for creating a new point or editing an existing one.
///
/// This form collects the point's name, type, assignments to Ordner and
/// the position on each stadium plan. It uses a tab bar to step
/// through the three stadium images so the user can specify a
/// coordinate for each plan. When saving, the point is persisted
/// to the `SharedPreferences` store under the key `points_all`. If
/// [existingPoint] is supplied the point will be updated instead of
/// created. A delete button is shown when editing.
class PointFormScreen extends StatefulWidget {
  /// List of all users registered in the system. Only users with the
  /// [UserRole.ordner] role can be assigned to a point.
  final List<User> users;

  /// Existing point to edit. If `null`, a new point will be created.
  final StadiumPoint? existingPoint;

  const PointFormScreen({Key? key, required this.users, this.existingPoint})
      : super(key: key);

  @override
  State<PointFormScreen> createState() => _PointFormScreenState();
}

class _PointFormScreenState extends State<PointFormScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  StadiumPointType _type = StadiumPointType.einfahrt;
  late List<Offset?> _positions;
  late Set<String> _assignedUsers;

  // Original dimensions of the three stadium images. These values
  // correspond to stadion1.png, stadion2.png and stadion3.png. They
  // ensure that the images are displayed at their intrinsic resolution
  // and that positions are calculated correctly across maps.
  static const List<Size> _imageSizes = [
    Size(958, 657),
    Size(987, 672),
    Size(1018, 803),
  ];

  static const List<String> _mapAssets = [
    'assets/stadion1.png',
    'assets/stadion2.png',
    'assets/stadion3.png',
  ];

  bool get isEditing => widget.existingPoint != null;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _mapAssets.length, vsync: this);
    if (isEditing) {
      final p = widget.existingPoint!;
      _nameController.text = p.name;
      _type = p.type;
      // Copy positions and pad/truncate to three entries
      _positions = List<Offset?>.from(p.positions);
      if (_positions.length < _mapAssets.length) {
        final Offset? last = _positions.isNotEmpty ? _positions.last : null;
        while (_positions.length < _mapAssets.length) {
          _positions.add(last);
        }
      } else if (_positions.length > _mapAssets.length) {
        _positions = _positions.sublist(0, _mapAssets.length);
      }
      _assignedUsers = Set<String>.from(p.assignedUsers);
    } else {
      _positions = List<Offset?>.filled(_mapAssets.length, null);
      _assignedUsers = <String>{};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Save the point to persistent storage. If editing, the existing
  /// point is updated; otherwise a new entry is appended. The method
  /// validates that all positions have been set.
  Future<void> _savePoint() async {
    if (!_formKey.currentState!.validate()) return;
    if (_positions.any((pos) => pos == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte wählen Sie eine Position auf allen Plänen'),
        ),
      );
      return;
    }
    final positions = _positions.map((e) => e!).toList();
    final String id = isEditing
        ? widget.existingPoint!.id
        : DateTime.now().millisecondsSinceEpoch.toString();
    final StadiumPoint newPoint = StadiumPoint(
      id: id,
      name: _nameController.text.trim(),
      type: _type,
      positions: positions,
      isReady: isEditing ? widget.existingPoint!.isReady : false,
      assignedUsers: _assignedUsers.toList(),
    );
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('points_all');
    List<dynamic> listJson;
    if (jsonString != null && jsonString.isNotEmpty) {
      listJson = jsonDecode(jsonString) as List<dynamic>;
    } else {
      listJson = [];
    }
    bool updated = false;
    for (int i = 0; i < listJson.length; i++) {
      if (listJson[i]['id'] == id) {
        listJson[i] = {
          'id': newPoint.id,
          'name': newPoint.name,
          'type': newPoint.type.name,
          'positions': newPoint.positions
              .map((pos) => {'dx': pos.dx, 'dy': pos.dy})
              .toList(),
          'isReady': newPoint.isReady,
          'assignedUsers': newPoint.assignedUsers,
        };
        updated = true;
        break;
      }
    }
    if (!updated) {
      listJson.add({
        'id': newPoint.id,
        'name': newPoint.name,
        'type': newPoint.type.name,
        'positions': newPoint.positions
            .map((pos) => {'dx': pos.dx, 'dy': pos.dy})
            .toList(),
        'isReady': newPoint.isReady,
        'assignedUsers': newPoint.assignedUsers,
      });
    }
    await prefs.setString('points_all', jsonEncode(listJson));
    Navigator.of(context).pop(true);
  }

  /// Delete the existing point from storage. Only available when editing.
  Future<void> _deletePoint() async {
    if (!isEditing) return;
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('points_all');
    if (jsonString != null && jsonString.isNotEmpty) {
      final listJson = jsonDecode(jsonString) as List<dynamic>;
      listJson.removeWhere((e) => e['id'] == widget.existingPoint!.id);
      await prefs.setString('points_all', jsonEncode(listJson));
    }
    Navigator.of(context).pop(true);
  }

  /// Helper to build the map selection area for a given index. It computes
  /// letterboxing so that the image is displayed at its original size
  /// (or scaled down proportionally) and centred. Taps inside the
  /// image update the relative position for that map.
  Widget _buildMapSelector(int index) {
    final imageSize = _imageSizes[index];
    final asset = _mapAssets[index];
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        double imageW;
        double imageH;
        double offX = 0;
        double offY = 0;
        // Calculate scale factor: never enlarge beyond original size.
        final double scale = [
          width / imageSize.width,
          height / imageSize.height,
          1.0
        ].reduce((a, b) => a < b ? a : b);
        imageW = imageSize.width * scale;
        imageH = imageSize.height * scale;
        offX = (width - imageW) / 2;
        offY = (height - imageH) / 2;
        final selected = _positions[index];
        return GestureDetector(
          onTapUp: (details) {
            final local = details.localPosition;
            if (local.dx >= offX &&
                local.dx <= offX + imageW &&
                local.dy >= offY &&
                local.dy <= offY + imageH) {
              final relX = (local.dx - offX) / imageW;
              final relY = (local.dy - offY) / imageH;
              setState(() {
                _positions[index] = Offset(relX, relY);
              });
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(color: Colors.white),
              ),
              Positioned(
                left: offX,
                top: offY,
                width: imageW,
                height: imageH,
                child: Image.asset(
                  asset,
                  fit: BoxFit.fill,
                ),
              ),
              if (selected != null)
                Positioned(
                  left: offX + selected.dx * imageW - 12,
                  top: offY + selected.dy * imageH - 12,
                  child: const Icon(
                    Icons.add_location,
                    color: Colors.yellow,
                    size: 24,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter ordner users for assignment. Only users with role Ordner can
    // be assigned to points. Admin and other roles cannot be assigned.
    final List<User> ordners =
        widget.users.where((u) => u.role == UserRole.ordner).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Punkt bearbeiten' : 'Punkt erstellen'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Punkt löschen?'),
                    content: const Text(
                        'Möchten Sie diesen Punkt unwiderruflich löschen?'),
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
                  await _deletePoint();
                }
              },
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Name and type form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Bezeichnung',
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
                  DropdownButtonFormField<StadiumPointType>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Typ',
                      border: OutlineInputBorder(),
                    ),
                    items: StadiumPointType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _type = value);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  // Assignment list: checkboxes for ordner
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Zuweisung an Ordner',
                      // Use titleMedium instead of the deprecated subtitle1.
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Column(
                    children: ordners
                        .map((u) => CheckboxListTile(
                              title: Text(u.username),
                              value: _assignedUsers.contains(u.username),
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _assignedUsers.add(u.username);
                                  } else {
                                    _assignedUsers.remove(u.username);
                                  }
                                });
                              },
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tabs for selecting positions on each plan
            TabBar(
              controller: _tabController,
              tabs: List.generate(
                _mapAssets.length,
                (i) => Tab(text: 'Plan ${i + 1}'),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: List.generate(
                  _mapAssets.length,
                  (i) => _buildMapSelector(i),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _savePoint,
              child: Text(isEditing ? 'Änderungen speichern' : 'Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}