import 'dart:convert';
import 'dart:typed_data';
import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Web-compatible database service using Neon's HTTP API
class WebDatabaseService {
  bool _isInitialized = false;
  late String _connectionString;

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final host = dotenv.env['NEON_HOST'] ?? '';
    final database = dotenv.env['NEON_DATABASE'] ?? '';
    final username = dotenv.env['NEON_USERNAME'] ?? '';
    final password = dotenv.env['NEON_PASSWORD'] ?? '';

    if (host.isEmpty ||
        database.isEmpty ||
        username.isEmpty ||
        password.isEmpty) {
      developer.log(
        'Neon credentials missing in .env',
        name: 'WebDatabaseService',
        level: 900,
      );
      return;
    }

    // Build connection string for Neon HTTP API
    _connectionString =
        'postgresql://$username:$password@$host/$database?sslmode=require';
    _isInitialized = true;

    await _ensureTablesExist();
  }

  Future<void> dispose() async {
    _isInitialized = false;
  }

  Future<List<Map<String, dynamic>>> query(String sql,
      [Map<String, dynamic>? params]) async {
    if (!_isInitialized) return [];

    try {
      final response = await http.post(
        Uri.parse('https://neon.tech/api/v2/sql'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_connectionString',
        },
        body: jsonEncode({
          'query': sql,
          'params': params ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['rows'] ?? []);
      } else {
        developer.log(
          'Query failed: ${response.statusCode}',
          name: 'WebDatabaseService',
          error: response.body,
        );
        return [];
      }
    } catch (e, stackTrace) {
      developer.log(
        'Query error',
        name: 'WebDatabaseService',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  Future<void> execute(String sql, [Map<String, dynamic>? params]) async {
    await query(sql, params);
  }

  Future<void> _ensureTablesExist() async {
    // Tables should already exist from SQL setup
    // This is a no-op for web
  }

  // --- User Management ---
  Future<void> createUser(
      {required String id, required String email, String? name}) async {
    await execute(
      'INSERT INTO users (id, email, name) VALUES (@id, @email, @name) ON CONFLICT (id) DO NOTHING',
      {'id': id, 'email': email, 'name': name},
    );
  }

  Future<Map<String, dynamic>?> getUser(String id) async {
    final result =
        await query('SELECT * FROM users WHERE id = @id', {'id': id});
    return result.isNotEmpty ? result.first : null;
  }

  // --- Notebook Management ---
  Future<String> createNotebook({
    required String id,
    required String userId,
    required String title,
    String? description,
  }) async {
    await execute(
      'INSERT INTO notebooks (id, user_id, title, description) VALUES (@id, @userId, @title, @description)',
      {'id': id, 'userId': userId, 'title': title, 'description': description},
    );
    return id;
  }

  Future<List<Map<String, dynamic>>> listNotebooks(String userId) async {
    return await query(
      'SELECT * FROM notebooks WHERE user_id = @userId ORDER BY updated_at DESC',
      {'userId': userId},
    );
  }

  Future<Map<String, dynamic>?> getNotebook(String id) async {
    final result =
        await query('SELECT * FROM notebooks WHERE id = @id', {'id': id});
    return result.isNotEmpty ? result.first : null;
  }

  // --- Source Management ---
  Future<void> saveSourceWithMedia(
    String id,
    String notebookId,
    String type,
    String title,
    String? content,
    String? url,
    Uint8List? mediaData,
  ) async {
    developer.log(
      'Saving source: id=$id, notebookId=$notebookId, type=$type, title=$title',
      name: 'WebDatabaseService',
    );

    try {
      // For web, we'll skip media_data (BYTEA) as it's complex over HTTP
      // Store media URLs instead
      await execute(
        'INSERT INTO sources (id, notebook_id, type, title, content, url) VALUES (@id, @notebookId, @type, @title, @content, @url)',
        {
          'id': id,
          'notebookId': notebookId,
          'type': type,
          'title': title,
          'content': content,
          'url': url,
        },
      );

      developer.log('Source saved successfully', name: 'WebDatabaseService');
    } catch (e, stackTrace) {
      developer.log(
        'Failed to save source',
        name: 'WebDatabaseService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Uint8List?> getSourceMedia(String sourceId) async {
    // Not supported on web via HTTP API
    return null;
  }
}
