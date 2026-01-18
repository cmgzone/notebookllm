# Image Optimization Script
# Replaces Image.network with CachedNetworkImage across the codebase

## Files to Update:
1. ✅ notebook_card.dart  
2. story_reader_screen.dart (3 instances)
3. story_generator_screen.dart  
4. web_search_screen.dart (6 instances)
5. notebook_cover_sheet.dart
6. infographic_viewer_screen.dart
7. infographics_list_screen.dart
8. ebook_reader_screen.dart (2 instances)  
9. enhanced_chat_screen.dart (3 instances)
10. voice_mode_screen.dart
11. onboarding_screen.dart

## Pattern:
Replace:
```dart
Image.network(
  url,
  ...
)
```

With:
```dart
CachedNetworkImage(
  imageUrl: url,
  placeholder: (context, url) => Container(color: Colors.grey[200]),
  ...
)
```
