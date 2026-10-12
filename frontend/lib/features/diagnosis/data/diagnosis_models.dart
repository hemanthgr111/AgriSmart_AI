// Crop-disease diagnosis models mirroring the backend `/api/diagnose` response.

class DiagnosisPrediction {
  const DiagnosisPrediction({
    required this.label,
    required this.crop,
    required this.disease,
    required this.isHealthy,
    required this.confidence,
    required this.advice,
  });

  final String label;
  final String crop;
  final String disease;
  final bool isHealthy;
  final double confidence;
  final String advice;

  factory DiagnosisPrediction.fromJson(Map<String, dynamic> json) =>
      DiagnosisPrediction(
        label: json['label'] as String? ?? '',
        crop: json['crop'] as String? ?? '',
        disease: json['disease'] as String? ?? '',
        isHealthy: json['is_healthy'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        advice: json['advice'] as String? ?? '',
      );
}

class DiagnosisResult {
  const DiagnosisResult({
    required this.crop,
    required this.disease,
    required this.isHealthy,
    required this.confidence,
    required this.advice,
    required this.predictions,
  });

  final String crop;
  final String disease;
  final bool isHealthy;
  final double confidence;
  final String advice;
  final List<DiagnosisPrediction> predictions;

  /// Runner-up predictions (everything after the top result).
  List<DiagnosisPrediction> get alternatives =>
      predictions.length <= 1 ? const <DiagnosisPrediction>[] : predictions.sublist(1);

  factory DiagnosisResult.fromJson(Map<String, dynamic> json) => DiagnosisResult(
        crop: json['crop'] as String? ?? '',
        disease: json['disease'] as String? ?? '',
        isHealthy: json['is_healthy'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
        advice: json['advice'] as String? ?? '',
        predictions: ((json['predictions'] as List<dynamic>?) ?? <dynamic>[])
            .map((dynamic e) =>
                DiagnosisPrediction.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
