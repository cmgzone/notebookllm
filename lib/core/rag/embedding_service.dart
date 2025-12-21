import 'package:dio/dio.dart';

class EmbeddingService {
  static const String _url = 'https://api.openai.com/v1/embeddings';
  static const String _model = 'text-embedding-3-small';

  final Dio _dio = Dio();

  EmbeddingService({required String apiKey}) {
    _dio.options.headers['Authorization'] = 'Bearer $apiKey';
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  Future<List<double>> embed(String text) async {
    final res = await _dio.post(_url, data: {
      'input': text,
      'model': _model,
    });
    final data = res.data['data'] as List;
    return (data.first['embedding'] as List).cast<double>();
  }
}