# Implementation Plan

- [x] 1. Set up project dependencies and configuration





  - Add required packages to pubspec.yaml (postgres, firebase_core, firebase_auth, flutter_dotenv)
  - Create .env.example file with required environment variables
  - Update .gitignore to exclude .env file
  - _Requirements: 1.1, 2.1, 7.1_

- [-] 2. Implement Firebase Auth Service


  - [x] 2.1 Create FirebaseAuthService class with authentication methods


    - Implement signUpWithEmail method
    - Implement signInWithEmail method
    - Implement signOut method
    - Implement sendPasswordResetEmail method
    - Add authStateChanges stream
    - Add currentUser getter
    - Add currentUserToken getter
    - _Requirements: 1.1, 1.2, 1.4_

  - [ ] 2.2 Write property test for valid credentials authentication





    - **Property 1.1: Valid credentials authenticate successfully**
    - **Validates: Requirements 1.1**

  - [ ] 2.3 Write property test for invalid credentials rejection
    - **Property 1.2: Invalid credentials are rejected**
    - **Validates: Requirements 1.2**

  - [ ] 2.4 Write property test for session expiration
    - **Property 1.3: Expired sessions require re-authentication**
    - **Validates: Requirements 1.3**

  - [ ] 2.5 Write property test for sign out invalidation
    - **Property 1.4: Sign out invalidates session**
    - **Validates: Requirements 1.4**

  - [x] 2.6 Create Riverpod providers for auth service and state

    - Create firebaseAuthServiceProvider
    - Create authStateChangesProvider
    - Create currentUserProvider
    - _Requirements: 1.1, 1.3_

- [-] 3. Implement connection pool for Neon database




















  - [x] 3.1 Create ConnectionPool class


    - Implement connection acquisition with pool size limits
    - Implement connection release mechanism
    - Add connection creation with retry logic
    - Add graceful shutdown method
    - _Requirements: 2.1, 2.2, 2.5_


  - [ ] 3.2 Write property test for connection acquisition and release
    - **Property 2.2: Connections are acquired and released**
    - **Validates: Requirements 2.2**

  - [ ] 3.3 Write property test for pool exhaustion queuing
    - **Property 2.3: Exhausted pool queues requests**
    - **Validates: Requirements 2.3**

  - [ ] 3.4 Write property test for connection retry with backoff
    - **Property 2.4: Connection failures trigger retry with backoff**
    - **Validates: Requirements 2.4**

- [-] 4. Implement NeonDatabaseService core functionality


  - [x] 4.1 Create NeonDatabaseService class with initialization


    - Load environment variables from .env
    - Initialize connection pool
    - Implement getConnection and releaseConnection methods
    - Add dispose method for cleanup
    - _Requirements: 2.1, 2.2, 2.5_

  - [x] 4.2 Implement schema initialization


    - Create _ensureTablesExist method
    - Add SQL for users table creation
    - Add SQL for notebooks table with indexes
    - Add SQL for sources table with indexes
    - Add SQL for chunks table with vector column
    - Add SQL for tags table
    - Add SQL for notebook_tags junction table
    - Enable pgvector extension
    - _Requirements: 7.1, 7.2, 7.3_

  - [ ] 4.3 Write example test for schema initialization


    - Verify all tables are created
    - Verify indexes exist
    - Verify foreign keys are established
    - _Requirements: 7.1, 7.2_

  - [ ] 4.4 Write property test for idempotent initialization
    - **Property 2.5: Initialization is idempotent**
    - **Validates: Requirements 7.5**

  - [ ] 4.5 Create Riverpod provider for database service
    - Create neonDatabaseServiceProvider
    - Initialize service on app startup
    - _Requirements: 2.1_

- [ ] 5. Implement user management operations
  - [ ] 5.1 Add user CRUD methods to NeonDatabaseService
    - Implement createUser method
    - Implement getUser method
    - Implement updateUser method (if needed)
    - _Requirements: 1.5_

  - [ ] 5.2 Write property test for user creation on registration
    - **Property 1.5: Registration creates both Firebase and database records**
    - **Validates: Requirements 1.5**

  - [ ] 5.3 Update auth flow to create database user on registration
    - Modify sign up flow to call createUser after Firebase registration
    - Handle errors if database user creation fails
    - _Requirements: 1.5_

- [/] Implement notebook CRUD operations
  - [x] 6.1 Add notebook methods to NeonDatabaseService
    - Implement createNotebook method with UUID generation
    - Implement listNotebooks method with ordering
    - Implement getNotebook method with ownership check
    - Implement updateNotebook method with timestamp update
    - Implement deleteNotebook method
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 6.2 Write property test for notebook creation
    - **Property 3.1: Notebook creation stores with unique ID**
    - **Validates: Requirements 3.1**

  - [x] 6.3 Write property test for notebook ordering
    - **Property 3.2: Notebooks are returned ordered by date**
    - **Validates: Requirements 3.2**

  - [x] 6.4 Write property test for notebook updates
    - **Property 3.3: Notebook updates modify data and timestamp**
    - **Validates: Requirements 3.3**

  - [x] 6.5 Write property test for cascade deletion
    - **Property 3.4: Notebook deletion cascades to sources and chunks**
    - **Validates: Requirements 3.4**

  - [x] 6.6 Write property test for ownership authorization
    - **Property 3.5: Users can only access their own notebooks**
    - **Validates: Requirements 3.5**

  - [x] 6.7 Update Notebook model to include all required fields
    - Add userId field
    - Add description field
    - Add createdAt field
    - Update fromJson to handle database format
    - _Requirements: 3.1_

  - [x] 6.8 Update NotebookProvider to use NeonDatabaseService
    - Replace existing backend calls with Neon service calls
    - Implement createNotebook method
    - Implement updateNotebook method
    - Implement deleteNotebook method
    - Add error handling
    - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [ ] 7. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement source CRUD operations
  - [ ] 8.1 Add source methods to NeonDatabaseService
    - Implement createSource method with media support
    - Implement listSources method
    - Implement getSource method
    - Implement updateSource method
    - Implement deleteSource method
    - Implement getSourceMedia method for binary data
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [ ] 8.2 Write property test for source creation
    - **Property 4.1: Source creation links to notebook**
    - **Validates: Requirements 4.1**

  - [ ] 8.3 Write property test for media round-trip
    - **Property 4.2: Media data round-trip preserves content**
    - **Validates: Requirements 4.2**

  - [ ] 8.4 Write property test for source retrieval
    - **Property 4.3: Source retrieval returns all notebook sources**
    - **Validates: Requirements 4.3**

  - [ ] 8.5 Write property test for source cascade deletion
    - **Property 4.4: Source deletion cascades to chunks**
    - **Validates: Requirements 4.4**

  - [ ] 8.6 Write property test for referential integrity
    - **Property 4.5: Source updates maintain referential integrity**
    - **Validates: Requirements 4.5**

  - [ ] 8.7 Update Source model to match database schema
    - Add notebookId field
    - Add updatedAt field
    - Update fromJson to handle database format
    - _Requirements: 4.1_

  - [ ] 8.8 Update SourceProvider to use NeonDatabaseService
    - Replace existing backend calls with Neon service calls
    - Implement createSource method with media handling
    - Implement deleteSource method
    - Add error handling
    - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 9. Implement chunk and embedding operations
  - [ ] 9.1 Add chunk methods to NeonDatabaseService
    - Implement createChunk method with vector storage
    - Implement listChunks method with ordering
    - Implement hasChunks method
    - Implement deleteChunks method
    - Implement searchSimilarChunks method with vector similarity
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

  - [ ] 9.2 Write property test for chunk storage
    - **Property 5.1: Chunks store with all required data**
    - **Validates: Requirements 5.1**

  - [ ] 9.3 Write property test for vector search
    - **Property 5.2: Vector search returns similar embeddings**
    - **Validates: Requirements 5.2**

  - [ ] 9.4 Write property test for chunk ordering
    - **Property 5.4: Chunks are ordered by index**
    - **Validates: Requirements 5.4**

  - [ ] 9.5 Write property test for chunk existence check
    - **Property 5.5: Chunk existence check is accurate**
    - **Validates: Requirements 5.5**

  - [ ] 9.6 Update RAG service to use Neon for chunk storage
    - Update ingestion service to call createChunk
    - Update vector store to use searchSimilarChunks
    - Add batch chunk insertion for performance
    - _Requirements: 5.1, 5.2_

- [ ] 10. Implement tag management operations
  - [ ] 10.1 Add tag methods to NeonDatabaseService
    - Implement createTag method
    - Implement listTags method
    - Implement deleteTag method
    - Implement addTagToNotebook method
    - Implement removeTagFromNotebook method
    - Implement getNotebookTags method
    - Implement listNotebooksByTag method
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [ ] 10.2 Write property test for tag creation
    - **Property 6.1: Tag creation associates with user**
    - **Validates: Requirements 6.1**

  - [ ] 10.3 Write property test for tag assignment
    - **Property 6.2: Tag assignment creates relationship**
    - **Validates: Requirements 6.2**

  - [ ] 10.4 Write property test for tag removal
    - **Property 6.3: Tag removal preserves tag**
    - **Validates: Requirements 6.3**

  - [ ] 10.5 Write property test for tag deletion cascade
    - **Property 6.4: Tag deletion cascades to relationships**
    - **Validates: Requirements 6.4**

  - [ ] 10.6 Write property test for tag filtering
    - **Property 6.5: Tag filtering returns correct notebooks**
    - **Validates: Requirements 6.5**

  - [ ] 10.7 Update TagProvider to use NeonDatabaseService
    - Replace existing backend calls with Neon service calls
    - Implement tag CRUD operations
    - Implement notebook-tag relationship management
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 11. Checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Implement error handling and logging
  - [ ] 12.1 Create DatabaseException class
    - Define error codes for different failure types
    - Add message and originalError fields
    - Implement toString for debugging
    - _Requirements: 8.1, 8.4_

  - [ ] 12.2 Add error handling to all database operations
    - Wrap all queries in try-catch blocks
    - Convert PostgreSQL exceptions to DatabaseException
    - Log errors with context (operation, user, timestamp)
    - Return meaningful errors to callers
    - _Requirements: 8.1, 8.4_

  - [ ] 12.3 Write property test for error logging
    - **Property 8.1: Database errors are logged and returned**
    - **Validates: Requirements 8.1**

  - [ ] 12.4 Write property test for auth error codes
    - **Property 8.2: Auth errors have specific codes**
    - **Validates: Requirements 8.2**

  - [ ] 12.5 Write property test for input validation
    - **Property 8.4: Invalid input is validated**
    - **Validates: Requirements 8.4**

  - [ ] 12.3 Add logging utility
    - Create Logger class or use logging package
    - Configure log levels (debug, info, warning, error)
    - Add structured logging for easy parsing
    - _Requirements: 8.1_

- [ ] 13. Implement transaction support
  - [ ] 13.1 Add transaction method to NeonDatabaseService
    - Implement transaction wrapper with begin/commit/rollback
    - Add error handling with automatic rollback
    - Add timeout handling
    - Add deadlock detection and retry
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_

  - [ ] 13.2 Write property test for transaction usage
    - **Property 9.1: Related operations use transactions**
    - **Validates: Requirements 9.1**

  - [ ] 13.3 Write property test for transaction rollback
    - **Property 8.5: Transaction failures rollback completely**
    - **Validates: Requirements 8.5**

  - [ ] 13.4 Write property test for transaction commit
    - **Property 9.3: Successful transactions commit atomically**
    - **Validates: Requirements 9.3**

  - [ ] 13.5 Write property test for deadlock retry
    - **Property 9.4: Deadlocks trigger retry**
    - **Validates: Requirements 9.4**

  - [ ] 13.6 Write property test for timeout handling
    - **Property 9.5: Timeouts cause rollback**
    - **Validates: Requirements 9.5**

  - [ ] 13.7 Update complex operations to use transactions
    - Wrap notebook creation with initial source in transaction
    - Wrap source deletion with chunk cleanup in transaction
    - _Requirements: 9.1_

- [ ] 14. Implement concurrency control
  - [ ] 14.1 Add optimistic locking to update operations
    - Add version or updated_at check to update queries
    - Return conflict error if timestamps don't match
    - Implement last-write-wins strategy
    - _Requirements: 10.3, 10.5_

  - [ ] 14.2 Write property test for optimistic locking
    - **Property 10.3: Concurrent updates use optimistic locking**
    - **Validates: Requirements 10.3**

  - [ ] 14.3 Write property test for conflict resolution
    - **Property 10.5: Conflicts resolved by timestamp**
    - **Validates: Requirements 10.5**

- [ ] 15. Update UI screens to use new backend
  - [ ] 15.1 Update login screen
    - Use FirebaseAuthService for authentication
    - Handle auth errors with user-friendly messages
    - Show loading states
    - _Requirements: 1.1, 1.2_

  - [ ] 15.2 Update home screen
    - Use NotebookProvider with Neon backend
    - Handle loading and error states
    - Test notebook creation and deletion
    - _Requirements: 3.1, 3.4_

  - [ ] 15.3 Update sources screen
    - Use SourceProvider with Neon backend
    - Handle media upload and display
    - Test source creation and deletion
    - _Requirements: 4.1, 4.2, 4.4_

  - [ ] 15.4 Update chat screen
    - Use Neon-backed RAG service for semantic search
    - Display citations from chunks
    - _Requirements: 5.2_

- [ ] 16. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 17. Performance optimization and cleanup
  - [ ] 17.1 Add database indexes
    - Verify all foreign key indexes exist
    - Add indexes for frequently queried columns
    - Create vector index for embedding search
    - _Requirements: 5.2_

  - [ ] 17.2 Implement batch operations
    - Add batch chunk insertion method
    - Optimize bulk data operations
    - _Requirements: 5.1_

  - [ ] 17.3 Add caching to providers
    - Cache user data after authentication
    - Cache notebook list with TTL
    - Invalidate cache on mutations
    - _Requirements: 3.2_

  - [ ] 17.4 Clean up old backend code
    - Remove Appwrite/Supabase service files
    - Remove unused dependencies
    - Update documentation
    - _Requirements: All_
