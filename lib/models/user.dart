// No imports required here; remove unused dart:convert import

/// Roles available for users of the stadium administration app. Each
/// role determines the permissions a user has within the app.
enum UserRole { admin, einsatzleiter, bereichsleiter, ordner }

/// Extension to get a human‑readable name for each [UserRole]. This is
/// used in the UI when displaying a user's role.
extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.einsatzleiter:
        return 'Einsatzleiter';
      case UserRole.bereichsleiter:
        return 'Bereichsleiter';
      case UserRole.ordner:
        return 'Ordner';
    }
  }
}

/// A simple user entity representing a system user with a username,
/// password and assigned role. In a production system you would not
/// store plain text passwords; this is for demonstration purposes only.
class User {
  String username;
  String password;
  UserRole role;

  User({
    required this.username,
    required this.password,
    required this.role,
  });

  /// Serializes the user into a JSON object for storage.
  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'role': role.name,
      };

  /// Deserializes a user from a JSON object.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'] as String,
      password: json['password'] as String,
      role: UserRole.values.firstWhere((r) => r.name == json['role']),
    );
  }
}