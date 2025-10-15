import 'dart:convert';

import 'package:mysql1/mysql1.dart';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
// The http package provides convenient helpers for making HTTP requests.
// It is used here for REST uploads to Google Cloud Storage via the
// googleapis_auth client.  Without this import, the extension methods
// (such as `post`) on http.Client would not be available.
import 'package:http/http.dart' as http;
// Firebase Storage is used to store uploaded plan files (images and PDFs)
// in the cloud.  When a file is uploaded, a download URL is returned which
// is then stored in the database instead of a local file path.  See
// https://pub.dev/packages/firebase_storage for details.
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'dart:io';
// Added for Google Cloud Storage REST API upload fallback.  The
// googleapis_auth package allows us to authenticate using a service
// account key and acquire OAuth2 credentials for Google APIs.  We
// alias the import to avoid name clashes with the firebase_auth
// package (not used here).  See https://pub.dev/packages/googleapis_auth
// for details.
// Import the auth_io entry point from googleapis_auth to use
// service account authentication.  The `auth_io.dart` library
// exports functions like clientViaServiceAccount, which are not
// available from the root googleapis_auth import.  See
// https://pub.dev/packages/googleapis_auth for details.
import 'package:googleapis_auth/auth_io.dart' as google_auth;
// The rootBundle is used to load the service account JSON file from
// the application's bundled assets.  This avoids exposing the
// credentials directly in source code and allows the file to be
// packaged alongside other assets.
import 'package:flutter/services.dart' show rootBundle;
// Note: we do not import path_provider here because the package may not be
// available by default.  Instead we save uploaded files into a local
// directory named `uploads` that sits alongside the `lib` and `assets`
// folders in the project root.  By writing directly into this folder
// relative to the application's current working directory we avoid
// introducing a dependency on `path_provider` while still giving the app
// a predictable location to persist user‑uploaded files.

/// Provides static methods for connecting to the MySQL database and
/// performing user related operations.  The connection settings
/// correspond to the environment described in the task description.
///
/// In a real world application you would avoid connecting directly
/// from a client and instead call a backend API.  This service
/// demonstrates a direct connection for educational purposes only.
class DbService {
  DbService._();

  /// Cache of locally saved map file paths keyed by map id.  When a plan
  /// or document is uploaded and persisted to disk, the returned relative
  /// path is recorded in this map alongside the newly created database
  /// record id.  During retrieval, [getStadiumMaps] consults this
  /// cache first to avoid hitting the database for the file location.
  ///
  /// This cache persists only for the lifetime of the application and
  /// is not written to disk.  It allows the UI to display previews of
  /// newly uploaded files immediately without needing to wait for a
  /// round trip to the database.  When the app restarts or when the
  /// cache does not contain an entry for a map id, the database value
  /// is used as a fallback.
  static final Map<int, String> _localMapPaths = {};

  /// Connection settings for the target MySQL server.  Adjust host,
  /// port, user and password if your environment changes.
  static final ConnectionSettings _settings = ConnectionSettings(
    host: '80.152.153.30',
    port: 3306,
    user: 'pss',
    password: 'psspassword',
    db: 'pss',
  );

  /// Name of the Cloud Storage bucket used when uploading via the REST API.
  /// This should match the bucket you created in the Firebase/Firebase
  /// console.  Do not include a domain suffix (.appspot.com or
  /// .firebasestorage.app) here when making requests to the Google
  /// Cloud Storage JSON API; only the bare bucket name is needed.
  static const String _storageBucketName = 'pss_security_bucket';

  /// Establishes a new connection to the database.  Each call to
  /// [authenticate] obtains and closes its own connection to avoid
  /// leaving sockets open.
  static Future<MySqlConnection> _connect() async {
    return await MySqlConnection.connect(_settings);
  }

  /// Validates the supplied [username] and [password].  On success
  /// a map containing the user id, username and role name is
  /// returned.  On failure `null` is returned.
  static Future<Map<String, Object>?> authenticate(
      String username, String password) async {
    final conn = await _connect();
    try {
      // Look up user by name.
      final results = await conn.query(
        'SELECT id, username, password_hash, role_id FROM users WHERE username = ?',
        [username],
      );
      if (results.isEmpty) {
        return null;
      }
      final row = results.first;
      final String storedHash = row['password_hash'] as String;
      final String incomingHash = sha256.convert(utf8.encode(password)).toString();
      if (storedHash != incomingHash) {
        return null;
      }
      // Retrieve role name.
      final roleResults = await conn.query(
        'SELECT name FROM roles WHERE id = ?',
        [row['role_id']],
      );
      String roleName = roleResults.isNotEmpty
          ? (roleResults.first['name'] as String)
          : '';
      return {
        'id': row['id'] as int,
        'username': row['username'] as String,
        'role': roleName,
      };
    } finally {
      await conn.close();
    }
  }

  /// Creates a new user with the given parameters.  The password is
  /// hashed using SHA‑256 before it is stored.  Only administrators
  /// should call this method.  Returns the newly created user id.
  static Future<int> createUser({
    required String username,
    required String password,
    required int roleId,
  }) async {
    final conn = await _connect();
    try {
      final String hash = sha256.convert(utf8.encode(password)).toString();
      final result = await conn.query(
        'INSERT INTO users (username, password_hash, role_id) VALUES (?, ?, ?)',
        [username, hash, roleId],
      );
      return result.insertId ?? 0;
    } finally {
      await conn.close();
    }
  }

  /// Updates the password for a given user.  The new password will be
  /// hashed using SHA‑256.
  static Future<void> updatePassword({
    required int userId,
    required String newPassword,
  }) async {
    final conn = await _connect();
    try {
      final String hash = sha256.convert(utf8.encode(newPassword)).toString();
      await conn.query(
        'UPDATE users SET password_hash = ? WHERE id = ?',
        [hash, userId],
      );
    } finally {
      await conn.close();
    }
  }

  /// Retrieves all users along with their roles.  Each map in the
  /// returned list contains the keys: id, username, role_id and
  /// role_name (may be null if the user has no role).
  static Future<List<Map<String, dynamic>>> getUsersWithRoles() async {
    final conn = await _connect();
    try {
      final results = await conn.query(
        'SELECT users.id, users.username, users.role_id, roles.name AS role_name '
        'FROM users LEFT JOIN roles ON users.role_id = roles.id ORDER BY users.id',
      );
      final users = <Map<String, dynamic>>[];
      for (final row in results) {
        users.add({
          'id': row['id'] as int,
          'username': row['username'] as String,
          'role_id': row['role_id'] as int?,
          'role_name': row['role_name'] as String?,
        });
      }
      return users;
    } finally {
      await conn.close();
    }
  }

  /// Retrieves all roles.  Each map contains id, name and description.
  static Future<List<Map<String, dynamic>>> getRoles() async {
    final conn = await _connect();
    try {
      final results = await conn.query(
        'SELECT id, name, description FROM roles ORDER BY id',
      );
      final roles = <Map<String, dynamic>>[];
      for (final row in results) {
        roles.add({
          'id': row['id'] as int,
          'name': row['name'] as String,
          'description': row['description'] as String?,
        });
      }
      return roles;
    } finally {
      await conn.close();
    }
  }

  /// Updates a user's username and role.
  static Future<void> updateUser({
    required int userId,
    required String username,
    required int? roleId,
  }) async {
    final conn = await _connect();
    try {
      await conn.query(
        'UPDATE users SET username = ?, role_id = ? WHERE id = ?',
        [username, roleId, userId],
      );
    } finally {
      await conn.close();
    }
  }

  /// Deletes a user by id.
  static Future<void> deleteUser(int userId) async {
    final conn = await _connect();
    try {
      await conn.query('DELETE FROM users WHERE id = ?', [userId]);
    } finally {
      await conn.close();
    }
  }

  /// Creates a new role.  Returns the id of the newly created role.
  static Future<int> createRole({
    required String name,
    String? description,
  }) async {
    final conn = await _connect();
    try {
      final result = await conn.query(
        'INSERT INTO roles (name, description) VALUES (?, ?)',
        [name, description],
      );
      return result.insertId ?? 0;
    } finally {
      await conn.close();
    }
  }

  /// Updates an existing role's name and description.
  static Future<void> updateRole({
    required int roleId,
    required String name,
    String? description,
  }) async {
    final conn = await _connect();
    try {
      await conn.query(
        'UPDATE roles SET name = ?, description = ? WHERE id = ?',
        [name, description, roleId],
      );
    } finally {
      await conn.close();
    }
  }

  /// Deletes a role.  Note: you should reassign or null out role_ids on
  /// users before deleting a role to avoid foreign key constraints.
  static Future<void> deleteRole(int roleId) async {
    final conn = await _connect();
    try {
      await conn.query('DELETE FROM roles WHERE id = ?', [roleId]);
    } finally {
      await conn.close();
    }
  }

  // --------------------------------------------------------------------------
  // Stadium related methods

  /// Uploads a plan file to the configured PHP endpoint.  The file
  /// should be provided as a list of bytes and the original name.  On
  /// success, the server is expected to return a JSON object with a
  /// `url` field pointing to the saved file location.  Throws an
  /// exception if the upload fails.

  /// Retrieves all stadiums.  Each map contains id, name, address,
  /// default_leader, default_leader_phone, default_leader_email and default_club.
  static Future<List<Map<String, dynamic>>> getStadiums() async {
    final conn = await _connect();
    try {
      final results = await conn.query(
        'SELECT id, name, address, default_leader, default_leader_phone, default_leader_email, default_club FROM stadiums ORDER BY id',
      );
      final stadiums = <Map<String, dynamic>>[];
      for (final row in results) {
        stadiums.add({
          'id': row['id'] as int,
          'name': row['name'] as String,
          'address': row['address'] as String?,
          'default_leader': row['default_leader'] as String?,
          'default_leader_phone': row['default_leader_phone'] as String?,
          'default_leader_email': row['default_leader_email'] as String?,
          'default_club': row['default_club'] as String?,
        });
      }
      return stadiums;
    } finally {
      await conn.close();
    }
  }

  /// Creates a new stadium and returns its id.  Optionally accepts a list
  /// of maps with keys 'name' and 'data' (Uint8List) representing the
  /// uploaded plans.  The number of maps should not exceed 5.
  static Future<int> createStadium({
    required String name,
    String? address,
    String? defaultLeader,
    String? defaultLeaderPhone,
    String? defaultLeaderEmail,
    String? defaultClub,
    List<Map<String, dynamic>>? plans,
  }) async {
    final conn = await _connect();
    try {
      final result = await conn.query(
        'INSERT INTO stadiums (name, address, default_leader, default_leader_phone, default_leader_email, default_club) VALUES (?, ?, ?, ?, ?, ?)',
        [name, address, defaultLeader, defaultLeaderPhone, defaultLeaderEmail, defaultClub],
      );
      final stadiumId = result.insertId ?? 0;
      if (plans != null) {
        for (final plan in plans) {
          // Ensure binary data is stored as Uint8List to allow proper
          // retrieval from the database.  Without this, mysql1 may
          // serialize lists into strings which cannot be decoded as
          // images later.
          final String originalName = plan['name'] as String;
          final dynamic d = plan['data'];
          Uint8List bytes;
          if (d is Uint8List) {
            bytes = d;
          } else if (d is List<int>) {
            bytes = Uint8List.fromList(d);
          } else {
            throw ArgumentError('Invalid plan data type');
          }
          // Attempt to store the file on disk.  If this fails, fall back
          // to a base64 representation so that the plan is not lost.
          String? savedPath;
          try {
            savedPath = await uploadPlanFile(bytes, originalName);
          } catch (_) {
            savedPath = null;
          }
          // Determine the data to store in the database.  When a local
          // file is saved, use its relative path (e.g. "uploads/1234_name.pdf").
          // Relative paths are resolved against the current working
          // directory when loading the file later.  If the file cannot
          // be saved, fall back to a base64 encoded representation.
          late final String dataToStore;
          if (savedPath != null && savedPath.isNotEmpty) {
            dataToStore = savedPath;
          } else {
            final String base64Str = base64.encode(bytes);
            dataToStore = base64Str;
          }
          // Insert the new plan into the stadium_maps table and capture its
          // insert id.  This id is used to associate a locally stored
          // file path with the corresponding database record so that
          // subsequent reads can bypass the database when loading
          // previews.
          final resultMap = await conn.query(
            'INSERT INTO stadium_maps (stadium_id, map_name, map_data) VALUES (?, ?, ?)',
            [stadiumId, originalName, dataToStore],
          );
          final int? insertedId = resultMap.insertId;
          // If a local file was successfully saved, record its absolute
          // path in the in-memory cache keyed by the newly inserted id.  This
          // allows the UI to display it immediately without reading
          // from the database.  Ignore cases where no local file exists.
          if (insertedId != null && savedPath != null && savedPath.isNotEmpty) {
            // Only record locally saved file paths (non-URLs) in the cache.  When
            // using Firebase Storage, uploadPlanFile returns a download URL.
            // Caching a URL as a file path would cause getStadiumMaps to
            // incorrectly attempt to load the remote file from the local
            // filesystem.  Therefore, only cache paths that do not look like
            // remote URLs.
            if (!savedPath.startsWith('http')) {
              _localMapPaths[insertedId] = savedPath;
            }
          }
        }
      }
      return stadiumId;
    } finally {
      await conn.close();
    }
  }

  // --------------------------------------------------------------------------
  // Event related methods

  /// Retrieves all events along with their associated stadium names.  Each
  /// returned map contains id, name, stadium_id, stadium_name,
  /// start_time, end_time and various optional metadata fields such as
  /// security_category, expected spectator counts, event leader contact
  /// details, participating clubs and a free‑text description.  Events
  /// are ordered by start time in descending order (most recent first).
  static Future<List<Map<String, dynamic>>> getEvents() async {
    final conn = await _connect();
    try {
      final results = await conn.query(
        'SELECT e.id, e.name, e.stadium_id, s.name AS stadium_name, '
        'e.start_time, e.end_time, e.security_category, '
        'e.expected_spectators_total, e.expected_home_supporters, '
        'e.expected_away_supporters, e.event_leader, e.event_leader_phone, '
        'e.event_leader_email, e.home_club, e.away_club, e.description, '
        'e.season, e.competition, e.matchday, e.kickoff_time, '
        'e.num_area_leaders, e.num_security, e.other_info '
        'FROM events e LEFT JOIN stadiums s ON e.stadium_id = s.id '
        'ORDER BY e.start_time DESC',
      );
      final events = <Map<String, dynamic>>[];
      for (final row in results) {
        events.add({
          'id': row['id'] as int,
          'name': row['name'] as String,
          'stadium_id': row['stadium_id'] as int?,
          'stadium_name': row['stadium_name'] as String?,
          'start_time': row['start_time'] as DateTime,
          'end_time': row['end_time'] as DateTime,
          'security_category': row['security_category'] as String?,
          'expected_spectators_total': row['expected_spectators_total'] as int?,
          'expected_home_supporters': row['expected_home_supporters'] as int?,
          'expected_away_supporters': row['expected_away_supporters'] as int?,
          'event_leader': row['event_leader'] as String?,
          'event_leader_phone': row['event_leader_phone'] as String?,
          'event_leader_email': row['event_leader_email'] as String?,
          'home_club': row['home_club'] as String?,
          'away_club': row['away_club'] as String?,
          'description': row['description'] as String?,
          'season': row['season'] as String?,
          'competition': row['competition'] as String?,
          'matchday': row['matchday'] as int?,
          'kickoff_time': row['kickoff_time'] as DateTime?,
          'num_area_leaders': row['num_area_leaders'] as int?,
          'num_security': row['num_security'] as int?,
          'other_info': row['other_info'] as String?,
        });
      }
      return events;
    } finally {
      await conn.close();
    }
  }

  /// Creates a new event and returns its id.  Various optional
  /// parameters allow specifying a stadium, security category,
  /// spectator estimates, leader contact information, participating
  /// clubs and an arbitrary description.  A list of role ids may be
  /// provided to associate roles with the event via the event_roles
  /// junction table.
  static Future<int> createEvent({
    required String name,
    int? stadiumId,
    required DateTime startTime,
    required DateTime endTime,
    String? securityCategory,
    int? expectedSpectatorsTotal,
    int? expectedHomeSupporters,
    int? expectedAwaySupporters,
    String? eventLeader,
    String? eventLeaderPhone,
    String? eventLeaderEmail,
    String? homeClub,
    String? awayClub,
    String? description,
    String? season,
    String? competition,
    int? matchday,
    DateTime? kickoffTime,
    int? numAreaLeaders,
    int? numSecurity,
    String? otherInfo,
    List<int>? roleIds,
  }) async {
    final conn = await _connect();
    try {
      final result = await conn.query(
        'INSERT INTO events '
        '(name, stadium_id, start_time, end_time, security_category, '
        'expected_spectators_total, expected_home_supporters, expected_away_supporters, '
        'event_leader, event_leader_phone, event_leader_email, home_club, away_club, description, '
        'season, competition, matchday, kickoff_time, num_area_leaders, num_security, other_info) '
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          name,
          stadiumId,
          startTime,
          endTime,
          securityCategory,
          expectedSpectatorsTotal,
          expectedHomeSupporters,
          expectedAwaySupporters,
          eventLeader,
          eventLeaderPhone,
          eventLeaderEmail,
          homeClub,
          awayClub,
          description,
          season,
          competition,
          matchday,
          kickoffTime,
          numAreaLeaders,
          numSecurity,
          otherInfo,
        ],
      );
      final int eventId = result.insertId ?? 0;
      if (roleIds != null) {
        for (final roleId in roleIds) {
          await conn.query(
            'INSERT INTO event_roles (event_id, role_id) VALUES (?, ?)',
            [eventId, roleId],
          );
        }
      }
      return eventId;
    } finally {
      await conn.close();
    }
  }

  /// Updates an existing event identified by [id].  All properties of the
  /// event, including optional fields, can be modified.  Existing
  /// role assignments are cleared and replaced with the provided list of
  /// [roleIds].  Pass an empty list to remove all roles.
  static Future<void> updateEvent({
    required int id,
    required String name,
    int? stadiumId,
    required DateTime startTime,
    required DateTime endTime,
    String? securityCategory,
    int? expectedSpectatorsTotal,
    int? expectedHomeSupporters,
    int? expectedAwaySupporters,
    String? eventLeader,
    String? eventLeaderPhone,
    String? eventLeaderEmail,
    String? homeClub,
    String? awayClub,
    String? description,
    String? season,
    String? competition,
    int? matchday,
    DateTime? kickoffTime,
    int? numAreaLeaders,
    int? numSecurity,
    String? otherInfo,
    List<int>? roleIds,
  }) async {
    final conn = await _connect();
    try {
      await conn.query(
        'UPDATE events SET name = ?, stadium_id = ?, start_time = ?, end_time = ?, '
        'security_category = ?, expected_spectators_total = ?, expected_home_supporters = ?, '
        'expected_away_supporters = ?, event_leader = ?, event_leader_phone = ?, '
        'event_leader_email = ?, home_club = ?, away_club = ?, description = ?, '
        'season = ?, competition = ?, matchday = ?, kickoff_time = ?, num_area_leaders = ?, '
        'num_security = ?, other_info = ? '
        'WHERE id = ?',
        [
          name,
          stadiumId,
          startTime,
          endTime,
          securityCategory,
          expectedSpectatorsTotal,
          expectedHomeSupporters,
          expectedAwaySupporters,
          eventLeader,
          eventLeaderPhone,
          eventLeaderEmail,
          homeClub,
          awayClub,
          description,
          season,
          competition,
          matchday,
          kickoffTime,
          numAreaLeaders,
          numSecurity,
          otherInfo,
          id,
        ],
      );
      // Remove existing role assignments
      await conn.query('DELETE FROM event_roles WHERE event_id = ?', [id]);
      // Reassign roles
      if (roleIds != null) {
        for (final roleId in roleIds) {
          await conn.query(
            'INSERT INTO event_roles (event_id, role_id) VALUES (?, ?)',
            [id, roleId],
          );
        }
      }
    } finally {
      await conn.close();
    }
  }

  /// Deletes an event and its role assignments.  All entries in
  /// event_roles referencing this event are removed prior to deleting
  /// the event itself to satisfy foreign key constraints.
  static Future<void> deleteEvent(int eventId) async {
    final conn = await _connect();
    try {
      await conn.query('DELETE FROM event_roles WHERE event_id = ?', [eventId]);
      await conn.query('DELETE FROM events WHERE id = ?', [eventId]);
    } finally {
      await conn.close();
    }
  }

  /// Retrieves a list of role ids associated with the given event.  If
  /// no roles are assigned, an empty list is returned.
  static Future<List<int>> getEventRoleIds(int eventId) async {
    final conn = await _connect();
    try {
      final results = await conn.query(
        'SELECT role_id FROM event_roles WHERE event_id = ?',
        [eventId],
      );
      final ids = <int>[];
      for (final row in results) {
        ids.add(row['role_id'] as int);
      }
      return ids;
    } finally {
      await conn.close();
    }
  }

  /// Updates an existing stadium's basic fields (not plans).  To update
  /// plans, call [addStadiumMap] and [deleteStadiumMap].
  static Future<void> updateStadium({
    required int id,
    required String name,
    String? address,
    String? defaultLeader,
    String? defaultLeaderPhone,
    String? defaultLeaderEmail,
    String? defaultClub,
  }) async {
    final conn = await _connect();
    try {
      await conn.query(
        'UPDATE stadiums SET name = ?, address = ?, default_leader = ?, default_leader_phone = ?, default_leader_email = ?, default_club = ? WHERE id = ?',
        [name, address, defaultLeader, defaultLeaderPhone, defaultLeaderEmail, defaultClub, id],
      );
    } finally {
      await conn.close();
    }
  }

  /// Deletes a stadium and all its associated maps.
  static Future<void> deleteStadium(int id) async {
    final conn = await _connect();
    try {
      await conn.query('DELETE FROM stadium_maps WHERE stadium_id = ?', [id]);
      await conn.query('DELETE FROM stadiums WHERE id = ?', [id]);
    } finally {
      await conn.close();
    }
  }

  /// Retrieves all maps associated with a stadium.  Each map returned
  /// contains id, map_name and map_data (binary).  Use this to display
  /// or manage existing plans.
  static Future<List<Map<String, dynamic>>> getStadiumMaps(int stadiumId) async {
    final conn = await _connect();
    try {
      final results = await conn.query(
        'SELECT id, map_name, map_data FROM stadium_maps WHERE stadium_id = ?',
        [stadiumId],
      );
      final maps = <Map<String, dynamic>>[];
      for (final row in results) {
        // rawData holds either a URL string, a file path (relative or absolute),
        // or base64/binary data.  We defer its interpretation until after
        // consulting the in‑memory cache of locally stored files.
        final dynamic rawData = row['map_data'];
        Uint8List? data;
        String? url;
        String? filePath;

        // Check for a locally cached file path first.  When a plan
        // was uploaded during this session the [createStadium] or
        // [addStadiumMap] methods will have recorded the returned
        // relative path in [_localMapPaths] keyed by the newly
        // inserted map id.  Using this cache avoids needing to
        // interpret rawData or query the database for a path.
        final int mapId = row['id'] as int;
        if (_localMapPaths.containsKey(mapId)) {
          filePath = _localMapPaths[mapId];
        }

        // If no local cache entry exists, interpret the raw data.  The
        // mysql1 driver returns LONGTEXT columns as Uint8List rather
        // than a String, so we decode it before examining its
        // contents.  Once a string is obtained we decide whether it
        // represents a remote URL, a file path or base64 encoded data.
        if (filePath == null) {
          String? stringValue;
          if (rawData is String) {
            stringValue = rawData;
          } else if (rawData is Uint8List) {
            stringValue = utf8.decode(rawData, allowMalformed: true);
          } else if (rawData is List<int>) {
            stringValue = utf8.decode(rawData, allowMalformed: true);
          }
          if (stringValue != null) {
            final str = stringValue;
            if (str.startsWith('http')) {
              // Remote URL returned by a server upload script; keep as URL.
              url = str;
            } else {
              // Heuristically determine whether the value is base64 or a file path.
              // If the string contains typical path separators (slash, backslash or
              // colon) we treat it as a path.  Otherwise we attempt to decode it
              // as base64; if decoding fails, we also treat it as a path.  This
              // handles absolute paths stored by uploadPlanFile as well as the
              // original base64 storage format.
              if (str.contains('/') || str.contains('\\') || str.contains(':')) {
                filePath = str;
              } else {
                try {
                  final decodedBytes = base64.decode(str);
                  data = Uint8List.fromList(decodedBytes);
                } catch (_) {
                  filePath = str;
                }
              }
            }
          }
        }

        // If a file system path was stored in the database, resolve it to
        // an absolute path and attempt to load image bytes for preview.
        // Relative paths (e.g. "upload/filename.png") are resolved against
        // the current working directory.  If the file exists and the
        // corresponding map name is not a PDF, its bytes are loaded
        // into [data] for preview.  The absolute path is then stored
        // back into [filePath] so that the UI can still access PDF
        // documents via File(path).
        if (filePath != null) {
          // Correct legacy singular 'upload' folder names to the plural
          // 'uploads'.  Some older records may contain a path like
          // ".../upload/..." or "...\\upload\\...".  Since the
          // application saves files into the "uploads" directory, swap
          // out the folder name when necessary before resolving the path.
          if (filePath.contains('/upload/')) {
            filePath = filePath.replaceFirst('/upload/', '/uploads/');
          }
          if (filePath.contains('\\upload\\')) {
            filePath = filePath.replaceFirst('\\upload\\', '\\uploads\\');
          }
          // Resolve relative paths to absolute paths.  When a path
          // begins with `assets/` on Windows, it refers to a file
          // stored within the Flutter debug assets directory
          // (build/windows/x64/runner/Debug/data/flutter_assets).
          String resolvedPath = filePath;
          final testFile = File(resolvedPath);
          if (!testFile.isAbsolute) {
            // Determine if the path is within the Flutter assets
            if (filePath.startsWith('assets/') || filePath.startsWith('assets\\')) {
              final Directory debugAssetsBase = Directory('${Directory.current.path}/build/windows/x64/runner/Debug/data/flutter_assets');
              resolvedPath = '${debugAssetsBase.path}/$filePath';
            } else {
              resolvedPath = '${Directory.current.path}/$filePath';
            }
          }
          try {
            final resolvedFile = File(resolvedPath);
            if (await resolvedFile.exists()) {
              // Update filePath to the absolute path so consumers can
              // locate the file correctly.
              filePath = resolvedFile.path;
              // Only load image data for non-PDF files; PDFs will still
              // be represented by an icon in the UI.
              final String mapName = (row['map_name'] as String).toLowerCase();
              if (!mapName.endsWith('.pdf')) {
                final bytes = await resolvedFile.readAsBytes();
                data ??= Uint8List.fromList(bytes);
              }
            }
          } catch (_) {
            // Ignore errors while resolving or reading the file.  The
            // UI will fall back to showing an icon if no preview is
            // available.
          }
        }

        // Emit a debug log to help diagnose why a preview may not appear.
        // The log shows the name of the map, whether binary data was loaded,
        // the resolved file path (if any) and URL (if any).  This can be
        // viewed in the console when running `flutter run --verbose`.
        try {
          // Use double quotes around the log string to avoid mixing with single
          // quotes used inside the interpolation (e.g. row['id']).
          print("[DbService.getStadiumMaps] id: ${row['id']}, name: ${row['map_name']}, hasData: ${data != null}, path: $filePath, url: $url");
        } catch (_) {}
        maps.add({
          'id': row['id'] as int,
          'map_name': row['map_name'] as String,
          'map_data': data,
          'map_url': url,
          'map_path': filePath,
        });
      }
      return maps;
    } finally {
      await conn.close();
    }
  }

  /// Adds a new map to a stadium.  Takes the binary [data] and a human
  /// readable [name].  Returns the id of the inserted map.
  static Future<int> addStadiumMap({
    required int stadiumId,
    required String name,
    required List<int> data,
  }) async {
    final conn = await _connect();
    try {
      // Convert the incoming list to a Uint8List to allow for
      // base64 encoding if the remote upload fails.  This mirrors
      // the behaviour in createStadium, where a fallback to a
      // base64 string ensures that the map is still stored in the
      // database even if the file cannot be uploaded to the remote
      // server.  Without this, the caller would silently lose the
      // uploaded file and the UI would show "Kein Vorschau verfügbar".
      final Uint8List bytes = Uint8List.fromList(data);
      // Attempt to persist the map to disk.  Fallback to base64
      // encoding if saving fails.  The uploadPlanFile method stores
      // files in the app's documents directory and returns a
      // relative path.  Convert this relative path into an
      // absolute path so that the file can be located across
      // sessions.
      String? savedPath;
      try {
        savedPath = await uploadPlanFile(bytes, name);
      } catch (_) {
        savedPath = null;
      }
      // Determine the data to store in the database.  When a local
      // file is saved, use its relative path.  Otherwise, fall back
      // to base64 encoding.
      late final String dataToStore;
      if (savedPath != null && savedPath.isNotEmpty) {
        dataToStore = savedPath;
      } else {
        final String base64Str = base64.encode(bytes);
        dataToStore = base64Str;
      }
      // Insert the new map and capture its id.  Use the id to
      // associate the saved file path with this record so the UI can
      // display it without querying the database again.  When
      // savedPath is null (fallback to base64) the map is not
      // recorded in the cache.
      final result = await conn.query(
        'INSERT INTO stadium_maps (stadium_id, map_name, map_data) VALUES (?, ?, ?)',
        [stadiumId, name, dataToStore],
      );
      final int? insertedId = result.insertId;
      if (insertedId != null && savedPath != null && savedPath.isNotEmpty) {
        // Only cache locally saved paths (non-URLs).  When the uploadPlanFile
        // returns a Firebase download URL, storing it as a local file path
        // causes incorrect attempts to load it from disk.  Skip caching
        // remote URLs.
        if (!savedPath.startsWith('http')) {
          _localMapPaths[insertedId] = savedPath;
        }
      }
      return insertedId ?? 0;
    } finally {
      await conn.close();
    }
  }

  /// Deletes an existing stadium map by id.
  static Future<void> deleteStadiumMap(int mapId) async {
    final conn = await _connect();
    try {
      await conn.query('DELETE FROM stadium_maps WHERE id = ?', [mapId]);
    } finally {
      await conn.close();
    }
  }

  // ------------------------------------------------------------------------
  // File upload helper

  /// Persists a stadium plan file to the local filesystem.
  ///
  /// In the original implementation of PSS, this method uploaded the file to
  /// a remote PHP script (`upload.php`) and returned the URL of the saved
  /// file.  However, when the `path_provider` plugin is unavailable or
  /// network connectivity is unreliable, storing uploads locally ensures
  /// that user‑provided documents are never lost.  This implementation
  /// writes the bytes to a `uploads` folder in the project root and
  /// returns a relative path (e.g. `uploads/1234_plan.png`).  Callers
  /// should store this string in the database and treat it either as a
  /// file path (if it contains path separators) or base64 data (if not).
  static Future<String?> uploadPlanFile(List<int> bytes, String filename) async {
    // Upload plan bytes to Firebase Storage and return the download URL.  Files
    // are stored in a dedicated `uploads` folder under the default bucket.  A
    // unique name is generated using the current timestamp and the original
    // filename (with disallowed characters replaced by underscores) to avoid
    // collisions.  If the upload fails, callers will fall back to a base64
    // encoded representation.
    // Attempt to upload the file to Firebase Storage.  If this fails (e.g.
    // because the Firebase Storage plugin is not available on the current
    // platform or the bucket is misconfigured) then fall back to saving
    // the file locally in the `uploads` directory relative to the project
    // root.  The returned string will be either a download URL (for
    // Firebase) or a relative path (for local files).
    // Sanitize filename: allow only alphanumeric characters, underscores,
    // dashes and dots to avoid invalid file names and path traversal.
    final sanitized = filename.replaceAll(RegExp(r'[^A-Za-z0-9_\.\-]'), '_');
    // Prefix the file name with a timestamp to ensure uniqueness.
    final uniqueName = '${DateTime.now().millisecondsSinceEpoch}_$sanitized';
    // Determine a reasonable content type based on the extension.
    String contentType;
    final lower = sanitized.toLowerCase();
    if (lower.endsWith('.pdf')) {
      contentType = 'application/pdf';
    } else if (lower.endsWith('.png')) {
      contentType = 'image/png';
    } else if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    } else {
      contentType = 'application/octet-stream';
    }
    // Convert the list of ints into a Uint8List for Firebase Storage.
    final Uint8List uploadData = Uint8List.fromList(bytes);
    // Attempt to upload the file to Firebase Storage first.  Even on
    // Windows we attempt the upload because the plugin may still work
    // depending on the environment.  If an exception occurs (for
    // example, due to platform channel issues or misconfiguration), we
    // fall back to saving the file locally.
    try {
      final metadata = firebase_storage.SettableMetadata(contentType: contentType);
      final firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('uploads/$uniqueName');
      await ref.putData(uploadData, metadata);
      final String downloadUrl = await ref.getDownloadURL();
      try {
        print("[DbService.uploadPlanFile] Uploaded $filename to Firebase with URL $downloadUrl");
      } catch (_) {}
      return downloadUrl;
    } catch (e) {
      try {
        print("[DbService.uploadPlanFile] Error uploading $filename to Firebase: $e");
      } catch (_) {}
      // Continue to REST API or local save fallback below
    }

    // If Firebase Storage upload fails (e.g. not supported on Windows),
    // attempt to upload using the Google Cloud Storage REST API.  This
    // method requires that you provide a service account JSON key in
    // your project's assets (see pubspec.yaml).  The key is loaded
    // via rootBundle and used to obtain an OAuth2 access token via
    // googleapis_auth.  On success, a publicly accessible download URL
    // is returned.  If the REST upload also fails, we fall back to
    // saving the file locally.
    try {
      final String? restUrl = await _uploadViaRest(uploadData, uniqueName, contentType);
      if (restUrl != null) {
        try {
          print("[DbService.uploadPlanFile] Uploaded $filename via REST to URL $restUrl");
        } catch (_) {}
        return restUrl;
      }
    } catch (e) {
      try {
        print("[DbService.uploadPlanFile] Error uploading $filename via REST: $e");
      } catch (_) {}
    }
    // Fallback: save locally
    try {
      final Directory uploadsDir = Directory('${Directory.current.path}/uploads');
      if (!uploadsDir.existsSync()) {
        uploadsDir.createSync(recursive: true);
      }
      final File file = File('${uploadsDir.path}/$uniqueName');
      await file.writeAsBytes(uploadData);
      final relativePath = 'uploads/$uniqueName';
      try {
        print("[DbService.uploadPlanFile] Saved $filename locally at $relativePath");
      } catch (_) {}
      return relativePath;
    } catch (e2) {
      try {
        print("[DbService.uploadPlanFile] Error saving $filename locally: $e2");
      } catch (_) {}
    }
    return null;
  }

  /// Attempts to upload a file to Google Cloud Storage via the JSON
  /// API using a service account.  The [data] parameter contains
  /// the binary bytes to upload, [uniqueName] is the filename
  /// relative to the `uploads` folder within the bucket, and
  /// [contentType] indicates the MIME type.  A publicly accessible
  /// download URL is returned on success.  If any step fails, `null`
  /// is returned.  Note that this method must be able to load a
  /// service account JSON from assets at
  /// `assets/service-account-key.json`.  See your project's
  /// pubspec.yaml for asset declarations.
  static Future<String?> _uploadViaRest(
      Uint8List data, String uniqueName, String contentType) async {
    try {
      // Load the service account credentials from the bundled assets.
      final String jsonKey = await rootBundle.loadString('assets/service-account-key.json');
      final Map<String, dynamic> keyMap = json.decode(jsonKey) as Map<String, dynamic>;
      final google_auth.ServiceAccountCredentials credentials =
          google_auth.ServiceAccountCredentials.fromJson(keyMap);
      // Define the scope for Cloud Storage read/write access.
      const List<String> scopes = ['https://www.googleapis.com/auth/devstorage.read_write'];
      final google_auth.AuthClient client =
          await google_auth.clientViaServiceAccount(credentials, scopes);
      final String bucket = _storageBucketName;
      final String objectPath = 'uploads/$uniqueName';
      final Uri uri = Uri.parse(
          'https://storage.googleapis.com/upload/storage/v1/b/$bucket/o?uploadType=media&name=$objectPath');
      final httpResponse = await client.post(uri,
          body: data, headers: {'Content-Type': contentType});
      if (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) {
        // Compute the direct download URL.  The Cloud Storage JSON API
        // returns a JSON object containing metadata about the upload,
        // including fields like "name" and "mediaLink".  However, we
        // can construct a stable URL using the bucket and object path.
        final String downloadUrl =
            'https://storage.googleapis.com/$bucket/$objectPath';
        return downloadUrl;
      } else {
        // Log the response body for debugging.  The body may contain
        // error details in JSON format.
        try {
          print('[DbService._uploadViaRest] Error response: ${httpResponse.statusCode} ${httpResponse.body}');
        } catch (_) {}
      }
    } catch (e) {
      try {
        print('[DbService._uploadViaRest] Exception: $e');
      } catch (_) {}
    }
    return null;
  }
}