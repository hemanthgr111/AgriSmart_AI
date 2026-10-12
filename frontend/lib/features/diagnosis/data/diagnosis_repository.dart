import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'diagnosis_models.dart';

/// Uploads a leaf photo to the backend for crop-disease classification.
class DiagnosisRepository {
  DiagnosisRepository(this._client);

  final ApiClient _client;

  Future<DiagnosisResult> diagnose({
    required List<int> bytes,
    required String filename,
  }) async {
    final Map<String, dynamic> json = await _client.postMultipart(
      '/api/diagnose',
      field: 'file',
      fileBytes: bytes,
      filename: filename,
    );
    return DiagnosisResult.fromJson(json);
  }
}

final Provider<DiagnosisRepository> diagnosisRepositoryProvider =
    Provider<DiagnosisRepository>(
  (ref) => DiagnosisRepository(ref.watch(apiClientProvider)),
);
