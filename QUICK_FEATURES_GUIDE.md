# Quick Features Guide

## 🚀 What's New

Your Notebook LLM app now has 15+ powerful new features!

## ✨ Key Features You Can Use Right Now

### 1. **Text Notes** 📝
- Click "+" in sources
- Select "Text Note"
- Write and save your notes
- Edit anytime by clicking the edit icon

### 2. **Search & Filter** 🔍
- Search bar at the top of sources list
- Filter by type (text, video, audio, etc.)
- Sort by date, title, or type
- Clear filters with one tap

### 3. **Edit & Delete** ✏️
- Edit text notes with the edit icon
- Delete any source with the delete icon
- Confirmation dialog prevents accidents

### 4. **Export & Share** 📤
```dart
// Export notebook as Markdown
await ExportService.shareNotebook(
  notebook: notebook,
  sources: sources,
);

// Share a single source
await ExportService.shareSource(source);
```

### 5. **Analytics Dashboard** 📊
- View total queries
- See average response time
- Track most queried topics
- Monitor source usage

### 6. **Tags** 🏷️
```dart
// Create a tag
final tagId = await ref.read(tagProvider.notifier)
  .createTag('Important', '#FF5722');

// Add tag to source
await ref.read(sourceProvider.notifier).updateSource(
  sourceId: sourceId,
  tagIds: [tagId],
);
```

## 📦 Setup Required

### 1. Add Dependencies
```yaml
# pubspec.yaml
dependencies:
  share_plus: ^7.2.1
  path_provider: ^2.1.1
  timeago: ^3.6.0
```

### 2. Run Migration
```bash
# Apply database changes
supabase db push

# Or manually
psql -h your-db-host -U postgres -d postgres -f supabase/migrations/20251119_add_all_features.sql
```

### 3. Rebuild Generated Files
```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## 🎯 Quick Usage Examples

### Search Sources
```dart
// Automatic - just type in the search bar
// Filter updates in real-time
```

### Delete a Source
```dart
await ref.read(sourceProvider.notifier).deleteSource(sourceId);
```

### Update a Source
```dart
await ref.read(sourceProvider.notifier).updateSource(
  sourceId: sourceId,
  title: 'New Title',
  content: 'Updated content',
);
```

### Track Analytics
```dart
final service = ref.read(analyticsServiceProvider);
await service.trackQuery(
  query: 'What is machine learning?',
  notebookId: notebookId,
  sourcesUsed: ['source1', 'source2'],
  responseTimeMs: 1500,
);
```

### View Analytics
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => AnalyticsScreen(notebookId: notebookId),
  ),
);
```

## 🗄️ New Database Tables

- `tags` - User-created tags
- `source_tags` - Tag assignments
- `notebook_sources` - Notebook-source links
- `source_comments` - Comments on sources
- `source_annotations` - Highlights and notes
- `query_analytics` - Usage tracking
- `notebook_shares` - Sharing functionality
- `offline_queue` - Offline sync queue

## 🔐 Security

All tables have Row Level Security (RLS) enabled:
- Users only see their own data
- Share tokens are unique and secure
- Optional expiration dates for shares

## 🎨 UI Improvements

- Modern card-based design
- Smooth animations
- Search with instant results
- Filter chips
- Confirmation dialogs
- Loading states
- Error handling

## 📱 User Flow

### Adding a Text Note
1. Open sources screen
2. Tap "+" button
3. Select "Text Note"
4. Enter title and content
5. Tap "Add Note"
6. Note appears in sources list

### Editing a Text Note
1. Find the note in sources list
2. Tap the edit icon
3. Modify title or content
4. Tap "Update Note"

### Searching Sources
1. Type in search bar
2. Results filter instantly
3. Clear with X button

### Filtering by Type
1. Tap filter icon in app bar
2. Select types to show
3. Active filters show as chips
4. Clear all with one tap

### Exporting a Notebook
1. Navigate to notebook
2. Tap share/export button
3. Choose format (Markdown)
4. Share via system sheet

## 🐛 Troubleshooting

### Build Errors
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### Database Errors
```bash
# Check migration status
supabase db diff

# Reset if needed
supabase db reset
```

### Missing Dependencies
```bash
flutter pub get
```

## 🚀 Next Steps

1. ✅ Run database migration
2. ✅ Add dependencies
3. ✅ Rebuild generated files
4. ✅ Test features
5. 🔄 Implement AI summaries (optional)
6. 🔄 Add voice input (optional)
7. 🔄 Enable sharing UI (optional)

## 📚 Documentation

- Code examples: See individual feature files

---

**Ready to use!** Most features work out of the box after migration.
