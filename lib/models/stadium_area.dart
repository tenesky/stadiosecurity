import 'package:flutter/material.dart';

/// Represents an area drawn on all stadium maps. An area is defined by a list
/// of vertex coordinates for each map (relative offsets 0..1). Each element
/// in [positions] corresponds to a stadium plan. The list of vertices for a
/// map may be empty if not defined yet.
class StadiumArea {
  final String id;
  final String name;
  final List<List<Offset>> positions;
  final int colorValue;
  final List<String> assignedUsers;
  /// Indicates whether the area is currently ready (green) or not (red).
  /// A ready area is rendered with a green status point on the stadium map.
  bool isReady;

  StadiumArea({
    required this.id,
    required this.name,
    required List<List<Offset>> positions,
    required this.colorValue,
    List<String>? assignedUsers,
    this.isReady = false,
  })  : positions = positions,
        assignedUsers = assignedUsers ?? [];

  StadiumArea copyWith({
    String? id,
    String? name,
    List<List<Offset>>? positions,
    int? colorValue,
    List<String>? assignedUsers,
    bool? isReady,
  }) {
    return StadiumArea(
      id: id ?? this.id,
      name: name ?? this.name,
      positions: positions ??
          this.positions
              .map((list) => List<Offset>.from(list))
              .toList(),
      colorValue: colorValue ?? this.colorValue,
      assignedUsers:
          assignedUsers ?? List<String>.from(this.assignedUsers),
      isReady: isReady ?? this.isReady,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'positions': positions
            .map((list) =>
                list.map((o) => {'dx': o.dx, 'dy': o.dy}).toList())
            .toList(),
        'color': colorValue,
        'assignedUsers': assignedUsers,
        'isReady': isReady,
      };

  factory StadiumArea.fromJson(Map<String, dynamic> json) {
    final posLists = <List<Offset>>[];
    if (json['positions'] is List) {
      for (final list in json['positions']) {
        final sub = <Offset>[];
        if (list is List) {
          for (final pos in list) {
            sub.add(Offset(
              (pos['dx'] as num).toDouble(),
              (pos['dy'] as num).toDouble(),
            ));
          }
        }
        posLists.add(sub);
      }
    }
    return StadiumArea(
      id: json['id'] as String,
      name: json['name'] as String,
      positions: posLists,
      colorValue: json['color'] as int,
      assignedUsers: (json['assignedUsers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isReady: json['isReady'] as bool? ?? false,
    );
  }
}