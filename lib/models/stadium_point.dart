import 'package:flutter/material.dart';

/// Enum describing the different categories of points displayed on
/// the stadium map. Extend this enum as needed when you introduce
/// additional point types (for example, toilets, first aid or VIP
/// areas).
/// Defines the available categories for stadium points.
/// These correspond to different types of access points and staff roles
/// within the stadium. Extend this enum as needed to represent additional
/// categories such as first aid, toilets or VIP areas.
enum StadiumPointType { einfahrt, eingang, tor, block, ordner }

/// Extension on [StadiumPointType] providing a human‑readable
/// `displayName`. This is used throughout the UI so that the enum
/// values themselves can remain concise while still exposing a
/// localized or friendly string.
extension StadiumPointTypeExtension on StadiumPointType {
  String get displayName {
    switch (this) {
      case StadiumPointType.einfahrt:
        return 'Einfahrt';
      case StadiumPointType.eingang:
        return 'Eingang';
      case StadiumPointType.tor:
        return 'Tor';
      case StadiumPointType.block:
        return 'Block';
      case StadiumPointType.ordner:
        return 'Ordner';
    }
  }
}

/// Immutable data structure representing a single point of interest
/// within a stadium map. Each point stores its position relative to
/// the underlying image, a textual name and a type. The [isReady]
/// flag indicates the operational state: when `true` the point is
/// highlighted in neon green, otherwise in neon red.
class StadiumPoint {
  final String id;
  final String name;
  final StadiumPointType type;
  /// A list of relative positions for this point on each stadium map. Each
  /// entry corresponds to a map index in the order the maps are defined
  /// in the application. Coordinates are normalised between 0 and 1. The
  /// list length should equal the number of stadium plans supported. When
  /// legacy points are loaded from storage that contain only a single
  /// coordinate, that position will be duplicated across all maps.
  final List<Offset> positions;
  bool isReady;
  /// Liste der zugewiesenen Benutzer (Benutzernamen) für diesen Punkt.
  /// Mehrere Ordner können demselben Punkt zugewiesen sein (n-zu-m-Beziehung).
  final List<String> assignedUsers;

  StadiumPoint({
    required this.id,
    required this.name,
    required this.type,
    required this.positions,
    this.isReady = false,
    List<String>? assignedUsers,
  }) : assignedUsers = assignedUsers ?? [];

  /// Convert this [StadiumPoint] instance into a serializable map.
  ///
  /// The returned map contains primitive values only: the [id],
  /// [name], [type] (stored as the enum's name), a list of
  /// coordinate objects for [positions], the [isReady] flag and the
  /// list of [assignedUsers]. Use this together with `jsonEncode`
  /// to persist points into storage.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'positions': positions
          .map((pos) => {'dx': pos.dx, 'dy': pos.dy})
          .toList(),
      'isReady': isReady,
      'assignedUsers': assignedUsers,
    };
  }

  /// Creates a [StadiumPoint] from a JSON representation.
  ///
  /// The [json] map must contain at least the keys `id`, `name` and
  /// `type`. Positions are expected to be a list where each entry
  /// contains `dx` and `dy` numeric coordinates. Missing fields are
  /// substituted with sensible defaults. Any unknown `type` value will
  /// fall back to [StadiumPointType.einfahrt].
  factory StadiumPoint.fromJson(Map<String, dynamic> json) {
    final List<Offset> pos = [];
    if (json['positions'] is List) {
      for (final dynamic p in json['positions'] as List) {
        if (p is Map) {
          final num? dx = p['dx'];
          final num? dy = p['dy'];
          if (dx != null && dy != null) {
            pos.add(Offset(dx.toDouble(), dy.toDouble()));
          }
        }
      }
    }
    final String typeName = json['type'] as String? ?? '';
    StadiumPointType resolvedType;
    try {
      resolvedType = StadiumPointType.values.firstWhere(
          (t) => t.name == typeName);
    } catch (_) {
      resolvedType = StadiumPointType.einfahrt;
    }
    return StadiumPoint(
      id: json['id'] as String,
      name: json['name'] as String,
      type: resolvedType,
      positions: pos,
      isReady: json['isReady'] as bool? ?? false,
      assignedUsers: (json['assignedUsers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  /// Creates a deep copy of this instance with optional overrides. Use
  /// this when updating fields rather than mutating them directly. In
  /// Flutter it's often preferable to rebuild widgets with updated
  /// models than to modify stateful objects in place.
  StadiumPoint copyWith({
    String? id,
    String? name,
    StadiumPointType? type,
    List<Offset>? positions,
    bool? isReady,
    List<String>? assignedUsers,
  }) {
    return StadiumPoint(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      positions: positions ?? List<Offset>.from(this.positions),
      isReady: isReady ?? this.isReady,
      assignedUsers: assignedUsers ?? List<String>.from(this.assignedUsers),
    );
  }
}