import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ingestion_service.dart';
import 'vector_store.dart';
import '../api/api_service.dart';

final ingestionServiceProvider = Provider((ref) => IngestionService());

final vectorStoreProvider = Provider((ref) {
  final api = ref.read(apiServiceProvider);
  return VectorStore(api);
});
