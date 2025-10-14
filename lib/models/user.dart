/// Simple user model used within the application.  It holds
/// identifying information along with a role name.  See
/// [DbService.authenticate] for how instances of this class are
/// created.
class User {
  final int id;
  final String username;
  final String role;

  User({required this.id, required this.username, required this.role});
}