# AI Services Backend Migration Plan

**Status**: In Progress  
**Started**: 2026-01-18  
**Goal**: Migrate all AI services to backend while maintaining beautiful streaming UIs and full history access

---

## ✅ Phase 1: Content Extraction (COMPLETED)

### Migrated Services:
1. **Google Drive Extraction** ✅
   - Endpoint: `/api/google-drive/extract`
   - Features: Docs, Sheets, Slides support
   - Status: Production ready

2. **YouTube Content Extraction** ✅
   - Endpoint: `/api/content/extract-youtube`
   - Features: Metadata + transcript extraction
   - Status: Production ready

3. **Web URL Extraction** ✅
   - Endpoint: `/api/content/extract-web`
   - Features: HTML parsing with Cheerio, metadata extraction
   - Status: Production ready

---

## 🚧 Phase 2: Research & Intelligence (IN PROGRESS)

### 1. Deep Research Service ✅
**Backend**: `deepResearchController.ts`  
**Endpoints**:
- `POST /api/research/deep` - Perform research with SSE streaming
- `GET /api/research/history` - Get research history
- `GET /api/research/session/:id` - Get session details

**Database Tables**:
- `research_sessions` - Stores research queries and results
- `research_sources` - Stores extracted sources

**Features**:
- ✅ Server-Sent Events (SSE) streaming
- ✅ Multi-step research process
- ✅ Full history storage
- ✅ Source extraction and analysis
- 🔄 AI summary generation (needs Gemini/OpenRouter integration)
- 🔄 Key insights extraction

**UI Requirements**:
- Stream research progress in real-time
- Show step-by-step progress
- Display sources as they're found
- Access past research sessions
- Beautiful animated progress indicators

---

## 📋 Phase 3: RAG & Embeddings (NEXT)

### Services to Migrate:
1. **Embedding Service**
   - Current: `embedding_service.dart`
   - Backend: Use pgvector in Neon
   - Benefits: Centralized vector storage, faster search

2. **Ingestion Service**
   - Current: `real_ingestion_service.dart`
   - Backend: Process chunks server-side
   - Benefits: Better control, batch processing

**Endpoints Needed**:
```typescript
POST /api/embeddings/generate    // Generate embeddings
POST /api/embeddings/search      // Semantic search
POST /api/ingestion/process      // Process source
GET  /api/ingestion/status/:id   // Get ingestion status
```

**Database**:
```sql
-- Add pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Store embeddings
ALTER TABLE chunks ADD COLUMN embedding vector(1536);
CREATE INDEX ON chunks USING ivfflat (embedding vector_cosine_ops);
```

---

## 🎙️ Phase 4: Speech Services (PLANNED)

### Services to Migrate:

1. **Text-to-Speech (TTS)**
   - Services: `elevenlabs_service.dart`, `google_cloud_tts_service.dart`, `murf_service.dart`
   - Backend benefits:
     - Cache generated audio (90% cost reduction)
     - CDN delivery via Bunny
     - Centralized API key management

**Endpoints**:
```typescript
POST /api/tts/generate           // Generate audio
GET  /api/tts/:id                // Get cached audio
GET  /api/tts/voices             // Get available voices
```

2. **Speech-to-Text (STT)**
   - Services: `ai_transcription_service.dart`, `deepgram_websocket_service.dart`
   - Backend benefits:
     - Better error handling
     - Transcription history
     - Cost optimization

**Endpoints**:
```typescript
POST /api/stt/transcribe         // Transcribe audio
WS   /api/stt/stream             // Real-time transcription
GET  /api/stt/history            // Transcription history
```

---

## 🎨 Phase 5: Image Generation (PLANNED)

### Services to Migrate:
1. **Image Generation**
   - Current: `image_generation_service.dart`
   - Backend: Cache generated images

2. **Cover Image Service**
   - Current: `cover_image_service.dart`
   - Backend: Generate and store on CDN

**Endpoints**:
```typescript
POST /api/images/generate        // Generate image
GET  /api/images/:id             // Get cached image
GET  /api/images/history         // Generation history
```

---

## 🌐 Phase 6: Web Services (PLANNED)

### Services to Migrate:
1. **Web Browsing Service**
   - Current: `web_browsing_service.dart`
   - Backend: Better proxy support, caching

**Endpoints**:
```typescript
POST /api/browse/page            // Browse and extract
GET  /api/browse/screenshot      // Get screenshot
```

---

## 📊 Migration Checklist

### For Each Service:

**Backend Setup**:
- [ ] Create controller with business logic
- [ ] Create routes with proper auth
- [ ] Add database tables/migrations
- [ ] Implement SSE streaming (if needed)
- [ ] Add error handling
- [ ] Add caching layer
- [ ] Write tests

**Frontend Updates**:
- [ ] Create/update API client methods  
- [ ] Update UI to use backend endpoints
- [ ] Maintain streaming UI animations
- [ ] Add history/past results view
- [ ] Handle offline states
- [ ] Add error states
- [ ] Update loading states

**Database**:
- [ ] Create migration SQL
- [ ] Add indexes for performance
- [ ] Set up foreign keys
- [ ] Add timestamps

**Testing**:
- [ ] Test streaming functionality
- [ ] Test history retrieval
- [ ] Test error scenarios
- [ ] Load testing for concurrent users

---

## 🎯 Success Criteria

For each migrated service:
1. ✅ **Streaming works** - Real-time updates in UI
2. ✅ **History works** - Can access past results
3. ✅ **Beautiful UI** - Smooth animations, clear progress
4. ✅ **Error handling** - Clear error messages
5. ✅ **Performance** - Faster than client-side
6. ✅ **Cost optimization** - Reduced API costs via caching
7. ✅ **Security** - API keys on backend only

---

## 📈 Expected Benefits

**Performance**:
- 3-5x faster processing (server-side)
- Better error recovery
- No timeout issues on mobile

**Cost**:
- 70-90% reduction in API costs (caching)
- Shared resources across users
- Better rate limiting

**UX**:
- Full history access
- Resume failed operations
- Offline support
- Better progress feedback

**Security**:
- No API keys in app
- Centralized auth
- Better data privacy

---

## 🚀 Deployment Strategy

1. **Deploy backend updates** (zero downtime)
2. **Run database migrations** 
3. **Deploy Flutter app** with backend integration
4. **Monitor logs** for errors
5. **Gradual rollout** to users

---

## 📝 Notes

- All streaming uses SSE (Server-Sent Events) for browser compatibility
- All history stored in PostgreSQL (Neon)
- All APIs require authentication
- All responses are cached where applicable
- All errors are properly logged and monitored

---

Last Updated: 2026-01-18
