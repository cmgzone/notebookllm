# Design Document: Neon + Firebase Backend

## Overview

This design document outlines the architecture for implementing a robust backend system for the Notebook LLM application using Neon (serverless PostgreSQL) for data persistence and Firebase Authentication for user management. The system will provide a clean separation between authentication, data access, and business logic layers while ensuring scalability, reliability, and maintainability.

The backend will support:
- User authentication and session management via Firebase
- Persistent storage of notebooks, sources, chunks, and embeddings in Neon PostgreSQL
- Vector similarity search using pgvector extension
- Efficient connection pooling and resource management
- Transaction support for data integrity
- Comprehensive error handling and logging

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter Application                      │
├─────────────────────────────────────────────────────────────┤
│                    Riverpod Providers                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Notebook   │  │    Source    │  │     Auth     │     │
│  │   Provider   │  │   Provider   │  │   Provider   │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                      Service Layer                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │    Neon      │  │   Firebase   │  │     RAG      │     │
│  │   Database   │  │     Auth     │  │   Service    │     │
│  │   Service    │  │   Service    │  │              │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    External Services                         │
│  ┌──────────────┐  ┌──────────────┐                        │
│  │     Neon     │  │   Firebase   │                        │
│  │  PostgreSQL  │  │     Auth     │                        │
│  └──────────────┘  └──────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities


**Firebase Auth Service**
- User authentication (sign up, sign in, sign out)
- Session token management
- User state monitoring
- Password reset and email verification

**Neon Database Service**
- Connection pool management
- CRUD operations for all entities
- Transaction management
- Query execution and result mapping
- Schema initialization and migrations

**RAG Service**
- Content chunking
- Embedding generation
- Vector similarity search
- Chunk retrieval and ranking

**Providers (Riverpod)**
- State management
- Service coordination
- UI data transformation
- Caching and optimistic updates

## Components and Interfaces

### 1. Firebase Auth Service

**Purpose**: Manage user authentication and session state

**Interface**:
```dart
class FirebaseAuthService {
  // Authentication
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  });
  
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  });
  
  Future<void> signOut();
  
  Future<void> sendPasswordResetEmail(String email);
  
  // State
  Stream<User?> get authStateChanges;
  User? get currentUser;
  Future<String?> get currentUserToken;
}
```

**Dependencies**: `firebase_auth` package

### 2. Neon Database Service

**Purpose**: Provide data persistence and retrieval operations

**Interface**:
```dart
class NeonDatabaseService {
  // Lifecycle
  Future<void> initialize();
  Future<void> dispose();
  
  // Connection Management
  Future<Connection> getConnection();
  Future<void> releaseConnection(Connection conn);
  
  // Users
  Future<void> createUser(String id, String email, String? name);
  Future<Map<String, dynamic>?> getUser(String id);
  
  // Notebooks
  Future<String> createNotebook({
    required String userId,
    required String title,
    String? description,
  });
  
  Future<List<Map<String, dynamic>>> listNotebooks(String userId);
  Future<Map<String, dynamic>?> getNotebook(String id);
  
  Future<void> updateNotebook({
    required String id,
    String? title,
    String? description,
  });
  
  Future<void> deleteNotebook(String id);
  
  // Sources
  Future<String> createSource({
    required String notebookId,
    required String type,
    required String title,
    String? content,
    String? url,
    Uint8List? mediaData,
  });
  
  Future<List<Map<String, dynamic>>> listSources(String notebookId);
  Future<Map<String, dynamic>?> getSource(String id);
  Future<void> updateSource(String id, Map<String, dynamic> updates);
  Future<void> deleteSource(String id);
  Future<Uint8List?> getSourceMedia(String sourceId);
  
  // Chunks
  Future<void> createChunk({
    required String sourceId,
    required String text,
    required int chunkIndex,
    required List<double> embedding,
  });
  
  Future<List<Map<String, dynamic>>> listChunks(String sourceId);
  Future<bool> hasChunks(String sourceId);
  Future<void> deleteChunks(String sourceId);
  
  // Vector Search
  Future<List<Map<String, dynamic>>> searchSimilarChunks({
    required List<double> queryEmbedding,
    required String notebookId,
    int limit = 10,
  });
  
  // Tags
  Future<String> createTag({
    required String userId,
    required String name,
    required String color,
  });
  
  Future<List<Map<String, dynamic>>> listTags(String userId);
  Future<void> deleteTag(String id);
  Future<void> addTagToNotebook(String notebookId, String tagId);
  Future<void> removeTagFromNotebook(String notebookId, String tagId);
  Future<List<String>> getNotebookTags(String notebookId);
  
  // Transactions
  Future<T> transaction<T>(Future<T> Function(Connection) action);
}
```

**Dependencies**: `postgres` package, `flutter_dotenv`

### 3. Enhanced Providers

**NotebookProvider**:
```dart
@riverpod
class NotebookNotifier extends _$NotebookNotifier {
  @override
  Future<List<Notebook>> build() async {
    final user = ref.watch(authStateChangesProvider).value;
    if (user == null) return [];
    
    final dbService = ref.watch(neonDatabaseServiceProvider);
    final results = await dbService.listNotebooks(user.uid);
    return results.map((r) => Notebook.fromJson(r)).toList();
  }
  
  Future<void> createNotebook(String title, String? description);
  Future<void> updateNotebook(String id, String title, String? description);
  Future<void> deleteNotebook(String id);
}
```

**SourceProvider**:
```dart
@riverpod
class SourceNotifier extends _$SourceNotifier {
  @override
  Future<List<Source>> build(String notebookId) async {
    final dbService = ref.watch(neonDatabaseServiceProvider);
    final results = await dbService.listSources(notebookId);
    return results.map((r) => Source.fromJson(r)).toList();
  }
  
  Future<void> createSource({
    required String notebookId,
    required String type,
    required String title,
    String? content,
    String? url,
    Uint8List? mediaData,
  });
  
  Future<void> deleteSource(String id);
}
```

## Data Models

### Database Schema

**users**
```sql
CREATE TABLE users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**notebooks**
```sql
CREATE TABLE notebooks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_notebooks_user_id ON notebooks(user_id);
CREATE INDEX idx_notebooks_updated_at ON notebooks(updated_at DESC);
```

**sources**
```sql
CREATE TABLE sources (
  id TEXT PRIMARY KEY,
  notebook_id TEXT NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT,
  url TEXT,
  media_data BYTEA,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sources_notebook_id ON sources(notebook_id);
CREATE INDEX idx_sources_type ON sources(type);
```

**chunks**
```sql
CREATE TABLE chunks (
  id TEXT PRIMARY KEY,
  source_id TEXT NOT NULL REFERENCES sources(id) ON DELETE CASCADE,
  content_text TEXT NOT NULL,
  chunk_index INTEGER NOT NULL,
  embedding VECTOR(1536),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_chunks_source_id ON chunks(source_id);
CREATE INDEX idx_chunks_embedding ON chunks USING ivfflat (embedding vector_cosine_ops);
```

**tags**
```sql
CREATE TABLE tags (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_tags_user_id ON tags(user_id);
```

**notebook_tags**
```sql
CREATE TABLE notebook_tags (
  notebook_id TEXT NOT NULL REFERENCES notebooks(id) ON DELETE CASCADE,
  tag_id TEXT NOT NULL REFERENCES tags(id) ON DELETE CASCADE,
  PRIMARY KEY (notebook_id, tag_id)
);

CREATE INDEX idx_notebook_tags_notebook ON notebook_tags(notebook_id);
CREATE INDEX idx_notebook_tags_tag ON notebook_tags(tag_id);
```

### Dart Models

Models use Freezed for immutability and JSON serialization:

**Notebook**
```dart
@freezed
class Notebook with _$Notebook {
  const factory Notebook({
    required String id,
    required String userId,
    required String title,
    String? description,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default([]) List<String> tagIds,
  }) = _Notebook;
  
  factory Notebook.fromJson(Map<String, dynamic> json);
}
```

**Source**
```dart
@freezed
class Source with _$Source {
  const factory Source({
    required String id,
    required String notebookId,
    required String type,
    required String title,
    String? content,
    String? url,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Source;
  
  factory Source.fromJson(Map<String, dynamic> json);
}
```

**Chunk**
```dart
@freezed
class Chunk with _$Chunk {
  const factory Chunk({
    required String id,
    required String sourceId,
    required String text,
    required int chunkIndex,
    required List<double> embedding,
  }) = _Chunk;
  
  factory Chunk.fromJson(Map<String, dynamic> json);
}
```


## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property Reflection

After analyzing all acceptance criteria, I identified the following redundancies:
- Property 5.3 (source deletion cascades to chunks) is redundant with Property 4.4
- Property 8.3 (connection retry with backoff) is redundant with Property 2.4
- Property 9.2 (transaction rollback on failure) is redundant with Property 8.5

These redundant properties have been consolidated to avoid duplicate testing.

### Authentication Properties

**Property 1.1: Valid credentials authenticate successfully**
*For any* valid email and password combination, when authentication is attempted, the Firebase Auth System should return a valid session token and user object.
**Validates: Requirements 1.1**

**Property 1.2: Invalid credentials are rejected**
*For any* invalid credential combination (wrong password, non-existent email, malformed email), the Firebase Auth System should reject the authentication and return a specific error code.
**Validates: Requirements 1.2**

**Property 1.3: Expired sessions require re-authentication**
*For any* authenticated session that has expired, attempts to access protected resources should fail and require re-authentication.
**Validates: Requirements 1.3**

**Property 1.4: Sign out invalidates session**
*For any* authenticated user, after signing out, the session token should be invalid and all authentication state should be cleared.
**Validates: Requirements 1.4**

**Property 1.5: Registration creates both Firebase and database records**
*For any* new user registration with valid email and password, both a Firebase Auth account and a corresponding Neon database user record should be created.
**Validates: Requirements 1.5**

### Connection Management Properties

**Property 2.2: Connections are acquired and released**
*For any* database operation, a connection should be acquired from the pool before execution and released after completion, regardless of success or failure.
**Validates: Requirements 2.2**

**Property 2.3: Exhausted pool queues requests**
*For any* scenario where all connections are in use, new requests should wait in a queue until a connection becomes available rather than failing immediately.
**Validates: Requirements 2.3**

**Property 2.4: Connection failures trigger retry with backoff**
*For any* connection failure, the service should attempt reconnection with exponentially increasing delays between attempts.
**Validates: Requirements 2.4, 8.3**

**Property 2.5: Initialization is idempotent**
*For any* number of initialization calls, the service should establish the connection pool only once and subsequent calls should be no-ops.
**Validates: Requirements 7.5**

### Notebook CRUD Properties

**Property 3.1: Notebook creation stores with unique ID**
*For any* valid title and description, creating a notebook should store it in the database with a unique ID and the correct user ID.
**Validates: Requirements 3.1**

**Property 3.2: Notebooks are returned ordered by date**
*For any* user with multiple notebooks, retrieving their notebooks should return all notebooks ordered by creation date (newest first).
**Validates: Requirements 3.2**

**Property 3.3: Notebook updates modify data and timestamp**
*For any* notebook update (title or description), the notebook record should be updated and the updated_at timestamp should be set to the current time.
**Validates: Requirements 3.3**

**Property 3.4: Notebook deletion cascades to sources and chunks**
*For any* notebook with associated sources and chunks, deleting the notebook should remove all sources and their chunks from the database.
**Validates: Requirements 3.4**

**Property 3.5: Users can only access their own notebooks**
*For any* notebook retrieval request, the service should return the notebook only if the requesting user is the owner.
**Validates: Requirements 3.5**

### Source Management Properties

**Property 4.1: Source creation links to notebook**
*For any* valid source data (type, title, content, URL), creating a source should store it linked to the specified notebook.
**Validates: Requirements 4.1**

**Property 4.2: Media data round-trip preserves content**
*For any* binary media data stored with a source, retrieving the media should return data identical to what was stored.
**Validates: Requirements 4.2**

**Property 4.3: Source retrieval returns all notebook sources**
*For any* notebook with sources, retrieving sources should return all sources belonging to that notebook.
**Validates: Requirements 4.3**

**Property 4.4: Source deletion cascades to chunks**
*For any* source with associated chunks, deleting the source should remove all chunks from the database.
**Validates: Requirements 4.4, 5.3**

**Property 4.5: Source updates maintain referential integrity**
*For any* source update, the operation should succeed without breaking foreign key relationships to notebooks.
**Validates: Requirements 4.5**

### Embedding and RAG Properties

**Property 5.1: Chunks store with all required data**
*For any* chunk creation, the chunk should be stored with text, embedding vector, chunk index, and source ID.
**Validates: Requirements 5.1**

**Property 5.2: Vector search returns similar embeddings**
*For any* query embedding, the vector search should return chunks ordered by cosine similarity to the query.
**Validates: Requirements 5.2**

**Property 5.4: Chunks are ordered by index**
*For any* source with multiple chunks, retrieving chunks should return them ordered by chunk_index in ascending order.
**Validates: Requirements 5.4**

**Property 5.5: Chunk existence check is accurate**
*For any* source, checking if chunks exist should return true if and only if at least one chunk exists for that source.
**Validates: Requirements 5.5**

### Tag Management Properties

**Property 6.1: Tag creation associates with user**
*For any* valid tag name and color, creating a tag should store it associated with the specified user ID.
**Validates: Requirements 6.1**

**Property 6.2: Tag assignment creates relationship**
*For any* notebook and tag, assigning the tag to the notebook should create a many-to-many relationship record.
**Validates: Requirements 6.2**

**Property 6.3: Tag removal preserves tag**
*For any* notebook-tag relationship, removing the tag from the notebook should delete the relationship but not delete the tag itself.
**Validates: Requirements 6.3**

**Property 6.4: Tag deletion cascades to relationships**
*For any* tag with notebook relationships, deleting the tag should remove all notebook-tag relationship records.
**Validates: Requirements 6.4**

**Property 6.5: Tag filtering returns correct notebooks**
*For any* tag, querying notebooks by that tag should return all and only notebooks that have that tag assigned.
**Validates: Requirements 6.5**

### Error Handling Properties

**Property 8.1: Database errors are logged and returned**
*For any* database operation that fails, the error should be logged with context and a meaningful error should be returned to the caller.
**Validates: Requirements 8.1**

**Property 8.2: Auth errors have specific codes**
*For any* authentication failure type (wrong password, user not found, network error), the Firebase Auth Service should return a distinct error code.
**Validates: Requirements 8.2**

**Property 8.4: Invalid input is validated**
*For any* invalid input data (null required fields, invalid formats), the service should validate and return clear validation errors before attempting database operations.
**Validates: Requirements 8.4**

**Property 8.5: Transaction failures rollback completely**
*For any* transaction where any operation fails, all changes made within that transaction should be rolled back and the database should remain in its pre-transaction state.
**Validates: Requirements 8.5, 9.2**

### Transaction Properties

**Property 9.1: Related operations use transactions**
*For any* set of related database operations (e.g., creating notebook and initial source), they should be executed within a single transaction.
**Validates: Requirements 9.1**

**Property 9.3: Successful transactions commit atomically**
*For any* transaction where all operations succeed, all changes should be committed atomically so they are all visible or none are visible.
**Validates: Requirements 9.3**

**Property 9.4: Deadlocks trigger retry**
*For any* transaction that encounters a deadlock, the service should detect it and retry the transaction with appropriate backoff.
**Validates: Requirements 9.4**

**Property 9.5: Timeouts cause rollback**
*For any* transaction that exceeds the timeout threshold, the service should rollback all changes and return a timeout error.
**Validates: Requirements 9.5**

### Concurrency Properties

**Property 10.3: Concurrent updates use optimistic locking**
*For any* concurrent update attempts on the same record, the service should use optimistic locking (e.g., version numbers or timestamps) to detect conflicts.
**Validates: Requirements 10.3**

**Property 10.5: Conflicts resolved by timestamp**
*For any* update conflict, the service should apply last-write-wins strategy by comparing updated_at timestamps.
**Validates: Requirements 10.5**


## Error Handling

### Error Categories

**Authentication Errors**
- `auth/invalid-email`: Malformed email address
- `auth/user-not-found`: No user with provided email
- `auth/wrong-password`: Incorrect password
- `auth/too-many-requests`: Rate limit exceeded
- `auth/network-request-failed`: Network connectivity issue

**Database Errors**
- `db/connection-failed`: Cannot establish database connection
- `db/query-failed`: SQL query execution failed
- `db/constraint-violation`: Foreign key or unique constraint violated
- `db/timeout`: Operation exceeded timeout threshold
- `db/deadlock`: Transaction deadlock detected

**Validation Errors**
- `validation/required-field`: Required field is missing
- `validation/invalid-format`: Data format is invalid
- `validation/unauthorized`: User not authorized for operation

### Error Handling Strategy

**Retry Logic**
- Connection failures: Exponential backoff (1s, 2s, 4s, 8s, max 30s)
- Deadlocks: Immediate retry up to 3 times
- Timeouts: No retry, return error to caller

**Error Propagation**
```dart
class DatabaseException implements Exception {
  final String code;
  final String message;
  final dynamic originalError;
  
  DatabaseException(this.code, this.message, [this.originalError]);
}

// Usage
try {
  await connection.execute(sql);
} on PostgreSQLException catch (e) {
  if (e.code == '23503') {
    throw DatabaseException(
      'db/constraint-violation',
      'Foreign key constraint violated',
      e,
    );
  }
  throw DatabaseException('db/query-failed', e.message, e);
}
```

**Logging**
- All errors logged with timestamp, user ID (if available), operation type
- Connection errors include host, database name (not credentials)
- Query errors include sanitized SQL (parameters removed)
- Use structured logging for easy parsing

## Testing Strategy

### Unit Testing

**Firebase Auth Service Tests**
- Sign up with valid/invalid emails
- Sign in with correct/incorrect passwords
- Sign out clears state
- Password reset sends email
- Auth state stream emits correctly

**Neon Database Service Tests**
- Connection pool initialization
- CRUD operations for each entity
- Foreign key constraints enforced
- Cascade deletions work correctly
- Transactions commit/rollback properly

**Provider Tests**
- Providers fetch data correctly
- Providers handle errors gracefully
- Optimistic updates work
- Cache invalidation on mutations

### Property-Based Testing

**Testing Framework**: Use `test` package with custom property testing utilities or `dart_check` package

**Configuration**: Each property test should run minimum 100 iterations with random inputs

**Test Structure**:
```dart
test('Property 3.1: Notebook creation stores with unique ID', () async {
  // Feature: neon-firebase-backend, Property 3.1
  final generator = NotebookDataGenerator();
  
  for (int i = 0; i < 100; i++) {
    final title = generator.randomTitle();
    final description = generator.randomDescription();
    final userId = generator.randomUserId();
    
    final id = await dbService.createNotebook(
      userId: userId,
      title: title,
      description: description,
    );
    
    expect(id, isNotEmpty);
    
    final notebook = await dbService.getNotebook(id);
    expect(notebook, isNotNull);
    expect(notebook!['title'], equals(title));
    expect(notebook['user_id'], equals(userId));
  }
});
```

**Property Test Coverage**:
- Authentication properties (1.1-1.5): Test with random valid/invalid credentials
- Connection management (2.2-2.5): Test with varying pool sizes and load
- CRUD properties (3.1-6.5): Test with random data generation
- Error handling (8.1-8.5): Test with injected failures
- Transaction properties (9.1-9.5): Test with random operation sequences
- Concurrency properties (10.3-10.5): Test with parallel operations

**Generators**:
```dart
class NotebookDataGenerator {
  String randomTitle() => 'Notebook ${Random().nextInt(10000)}';
  String randomDescription() => 'Description ${Random().nextInt(10000)}';
  String randomUserId() => 'user_${Random().nextInt(1000)}';
}

class SourceDataGenerator {
  String randomType() => ['url', 'text', 'youtube', 'drive'][Random().nextInt(4)];
  String randomTitle() => 'Source ${Random().nextInt(10000)}';
  String randomContent() => 'Content ' * Random().nextInt(100);
  Uint8List randomMedia() => Uint8List.fromList(
    List.generate(Random().nextInt(1000), (_) => Random().nextInt(256))
  );
}
```

### Integration Testing

**End-to-End Flows**:
1. User registration → Create notebook → Add source → Query chunks
2. User login → List notebooks → Update notebook → Delete notebook
3. Create source → Process chunks → Semantic search → Retrieve results
4. Create tags → Assign to notebooks → Filter by tag → Remove tag

**Test Database**:
- Use separate test database instance
- Reset schema before each test suite
- Clean up data after each test

### Example Tests

**Example Test 2.1: Connection pool initialization**
```dart
test('Connection pool initializes with configured size', () async {
  final service = NeonDatabaseService();
  await service.initialize();
  
  // Verify pool is created (implementation-specific check)
  expect(service.isInitialized, isTrue);
});
```

**Example Test 7.1: Schema initialization**
```dart
test('Schema creates all required tables', () async {
  final service = NeonDatabaseService();
  await service.initialize();
  
  final tables = await service.query(
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"
  );
  
  final tableNames = tables.map((t) => t['tablename']).toList();
  expect(tableNames, contains('users'));
  expect(tableNames, contains('notebooks'));
  expect(tableNames, contains('sources'));
  expect(tableNames, contains('chunks'));
  expect(tableNames, contains('tags'));
  expect(tableNames, contains('notebook_tags'));
});
```

## Implementation Notes

### Connection Pooling

The `postgres` package doesn't provide built-in connection pooling. We'll implement a simple pool:

```dart
class ConnectionPool {
  final List<Connection> _available = [];
  final List<Connection> _inUse = [];
  final int maxSize;
  
  Future<Connection> acquire() async {
    if (_available.isNotEmpty) {
      final conn = _available.removeLast();
      _inUse.add(conn);
      return conn;
    }
    
    if (_inUse.length < maxSize) {
      final conn = await _createConnection();
      _inUse.add(conn);
      return conn;
    }
    
    // Wait for available connection
    while (_available.isEmpty) {
      await Future.delayed(Duration(milliseconds: 100));
    }
    return acquire();
  }
  
  void release(Connection conn) {
    _inUse.remove(conn);
    _available.add(conn);
  }
}
```

### Vector Search

Requires pgvector extension:

```sql
CREATE EXTENSION IF NOT EXISTS vector;

-- Create index for fast similarity search
CREATE INDEX idx_chunks_embedding ON chunks 
USING ivfflat (embedding vector_cosine_ops)
WITH (lists = 100);

-- Query similar chunks
SELECT id, content_text, 1 - (embedding <=> @query_embedding) as similarity
FROM chunks
WHERE source_id IN (SELECT id FROM sources WHERE notebook_id = @notebook_id)
ORDER BY embedding <=> @query_embedding
LIMIT 10;
```

### Environment Configuration

Required `.env` variables:

```
# Neon Database
NEON_HOST=your-project.neon.tech
NEON_DATABASE=your_database
NEON_USERNAME=your_username
NEON_PASSWORD=your_password

# Firebase
FIREBASE_API_KEY=your_api_key
FIREBASE_PROJECT_ID=your_project_id
FIREBASE_APP_ID=your_app_id
```

### Migration Strategy

For existing apps with data:

1. **Backup existing data** from current backend
2. **Deploy Neon database** with schema
3. **Migrate user data** from Firebase to Neon users table
4. **Migrate notebooks, sources, chunks** with ID preservation
5. **Verify data integrity** with checksums
6. **Switch app** to use new services
7. **Monitor** for errors and rollback if needed

### Performance Considerations

**Indexing**:
- Index all foreign keys for join performance
- Index frequently queried columns (user_id, notebook_id, type)
- Use partial indexes for filtered queries
- Monitor query performance and add indexes as needed

**Caching**:
- Cache user data in memory after authentication
- Cache notebook list with TTL of 5 minutes
- Invalidate cache on mutations
- Use Riverpod's built-in caching

**Batch Operations**:
- Batch chunk insertions (100 at a time)
- Use COPY for bulk data imports
- Batch embedding generation requests

**Connection Management**:
- Pool size: 10 connections for mobile app
- Connection timeout: 30 seconds
- Query timeout: 60 seconds
- Idle connection cleanup: 5 minutes

## Security Considerations

**Authentication**:
- Never store passwords in database (Firebase handles this)
- Use Firebase session tokens for API authentication
- Validate tokens on every request
- Implement rate limiting for auth endpoints

**Authorization**:
- Always check user ownership before operations
- Use parameterized queries to prevent SQL injection
- Validate all user inputs
- Sanitize error messages (don't leak schema details)

**Data Protection**:
- Use SSL/TLS for all database connections
- Encrypt sensitive data at rest (if required)
- Implement audit logging for sensitive operations
- Regular security audits and dependency updates

**API Keys**:
- Store in `.env` file (never commit)
- Use different keys for dev/staging/production
- Rotate keys periodically
- Monitor for unauthorized usage

## Deployment Checklist

- [ ] Neon database provisioned
- [ ] pgvector extension enabled
- [ ] Database schema deployed
- [ ] Indexes created
- [ ] Firebase project configured
- [ ] Environment variables set
- [ ] Connection pool tested
- [ ] All unit tests passing
- [ ] All property tests passing
- [ ] Integration tests passing
- [ ] Error handling verified
- [ ] Logging configured
- [ ] Performance benchmarks met
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Monitoring and alerts configured

