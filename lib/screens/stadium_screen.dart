import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/stadium_point.dart';
import '../models/stadium_area.dart';
import '../models/user.dart';
import '../widgets/stadium_map.dart';
import 'point_form_screen.dart';
import 'area_form_screen.dart';
import 'resources_list_screen.dart';

/// Displays the three stadium plans with all points and areas.
/// Points and areas are shared across all plans. Editing a point or area
/// affects all plans. Admins and Einsatzleiter can create, edit and delete
/// points and areas. Bereichsleiter can view all points/areas but not edit.
/// Ordner see only points and areas assigned to them.
class StadiumScreen extends StatefulWidget {
  final User currentUser;
  final List<User> users;

  const StadiumScreen({
    super.key,
    required this.currentUser,
    required this.users,
  });

  @override
  State<StadiumScreen> createState() => _StadiumScreenState();
}

class _StadiumScreenState extends State<StadiumScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Asset paths for the three stadium images.
  final List<String> _mapAssets = const [
    'assets/stadion1.png',
    'assets/stadion2.png',
    'assets/stadion3.png',
  ];
  // Original sizes of the images in pixels.
  final List<Size> _imageSizes = const [
    Size(958, 657),
    Size(987, 672),
    Size(1018, 803),
  ];

  List<StadiumPoint> _points = [];
  List<StadiumArea> _areas = [];

  bool get _canEditPoints =>
      widget.currentUser.role == UserRole.admin ||
      widget.currentUser.role == UserRole.einsatzleiter;

  bool _isPointVisible(StadiumPoint p) {
    if (_canEditPoints || widget.currentUser.role == UserRole.bereichsleiter) {
      return true;
    }
    if (widget.currentUser.role == UserRole.ordner) {
      return p.assignedUsers.contains(widget.currentUser.username);
    }
    return true;
  }

  bool _isAreaVisible(StadiumArea a) {
    if (_canEditPoints || widget.currentUser.role == UserRole.bereichsleiter) {
      return true;
    }
    if (widget.currentUser.role == UserRole.ordner) {
      return a.assignedUsers.contains(widget.currentUser.username);
    }
    return true;
  }

  bool _canTogglePoint(StadiumPoint p) {
    if (_canEditPoints) return true;
    if (widget.currentUser.role == UserRole.ordner) {
      return p.assignedUsers.contains(widget.currentUser.username);
    }
    return false;
  }

  bool _canToggleArea(StadiumArea a) {
    if (_canEditPoints) return true;
    if (widget.currentUser.role == UserRole.ordner) {
      return a.assignedUsers.contains(widget.currentUser.username);
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _mapAssets.length, vsync: this);
    _loadData();
  }

  /// Loads all points and areas from persistent storage (SharedPreferences).
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final pointsString = prefs.getString('points_all');
    final areasString = prefs.getString('areas_all');
    if (pointsString != null && pointsString.isNotEmpty) {
      final decoded = jsonDecode(pointsString) as List<dynamic>;
      _points = decoded
          .map((e) => StadiumPoint.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _points = [];
    }
    if (areasString != null && areasString.isNotEmpty) {
      final decoded = jsonDecode(areasString) as List<dynamic>;
      _areas = decoded
          .map((e) => StadiumArea.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      _areas = [];
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _savePoints() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _points.map((p) => p.toJson()).toList(growable: false);
    await prefs.setString('points_all', jsonEncode(data));
  }

  Future<void> _saveAreas() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _areas.map((a) => a.toJson()).toList(growable: false);
    await prefs.setString('areas_all', jsonEncode(data));
  }


  void _togglePoint(StadiumPoint point) {
    setState(() {
      final idx = _points.indexWhere((p) => p.id == point.id);
      if (idx >= 0) {
        _points[idx] =
            _points[idx].copyWith(isReady: !_points[idx].isReady);
      }
    });
    _savePoints();
    // Notify user of change
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status für Punkt "${point.name}" geändert')),
    );
  }

  void _toggleArea(StadiumArea area) {
    setState(() {
      final idx = _areas.indexWhere((a) => a.id == area.id);
      if (idx >= 0) {
        _areas[idx] =
            _areas[idx].copyWith(isReady: !_areas[idx].isReady);
      }
    });
    _saveAreas();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status für Bereich "${area.name}" geändert')),
    );
  }

  Future<void> _editPoint(StadiumPoint point) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PointFormScreen(
          users: widget.users,
          // Pass the point being edited via the existingPoint parameter.
          existingPoint: point,
        ),
      ),
    );
    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _createPoint() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PointFormScreen(
          users: widget.users,
        ),
      ),
    );
    if (changed == true) {
      await _loadData();
    }
  }

  Future<void> _createArea() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AreaFormScreen(
          users: widget.users,
        ),
      ),
    );
    if (changed == true) {
      await _loadData();
    }
  }


  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _mapAssets.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Stadionübersicht'),
          bottom: TabBar(
            controller: _tabController,
            tabs: List.generate(
              _mapAssets.length,
              (i) => Tab(text: 'Plan ${i + 1}'),
            ),
          ),
          actions: [
            // Combined list icon: shows all points and areas in a single
            // overview with edit/delete options for authorised users.
            IconButton(
              icon: const Icon(Icons.list),
              tooltip: 'Punkte/Bereiche anzeigen',
              onPressed: () {
                Navigator.of(context)
                    .push<bool>(
                  MaterialPageRoute(
                    builder: (_) => ResourcesListScreen(
                      currentUser: widget.currentUser,
                      users: widget.users,
                    ),
                  ),
                )
                    .then((changed) async {
                  if (changed == true) {
                    await _loadData();
                  }
                });
              },
            ),
            if (_canEditPoints) ...[
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Punkt erstellen',
                onPressed: _createPoint,
              ),
              IconButton(
                icon: const Icon(Icons.add_to_photos),
                tooltip: 'Bereich erstellen',
                onPressed: _createArea,
              ),
            ],
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: List.generate(_mapAssets.length, (i) {
            final displayedPoints =
                _points.where(_isPointVisible).toList();
            final displayedAreas =
                _areas.where(_isAreaVisible).toList();
            return StadiumMap(
              imageAsset: _mapAssets[i],
              points: displayedPoints,
              areas: displayedAreas,
              mapIndex: i,
              originalWidth: _imageSizes[i].width,
              originalHeight: _imageSizes[i].height,
              onTogglePoint: (p) {
                if (_canTogglePoint(p)) {
                  _togglePoint(p);
                }
              },
              onLongPressPoint: _canEditPoints ? (p) => _editPoint(p) : null,
              onToggleArea: (a) {
                if (_canToggleArea(a)) {
                  _toggleArea(a);
                }
              },
            );
          }),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}