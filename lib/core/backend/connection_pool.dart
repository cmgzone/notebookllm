// STUB FILE - Connection pool no longer needed
// Database connections are now handled by the backend API

import 'package:flutter/foundation.dart';

class ConnectionPool {
  ConnectionPool({
    required String host,
    required String database,
    required String username,
    required String password,
    int port = 5432,
    int maxConnections = 5,
  }) {
    debugPrint(
        '⚠️ ConnectionPool created - database now handled by backend API');
  }

  Future<void> close() async {}
}
