/// Backend health snapshot returned by `GET /api/health`.
class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.app,
    required this.version,
    required this.environment,
    required this.database,
    this.timestamp,
  });

  final String status;
  final String app;
  final String version;
  final String environment;
  final String database;
  final DateTime? timestamp;

  bool get isDatabaseConnected => database == 'connected';

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      app: json['app'] as String? ?? '',
      version: json['version'] as String? ?? '',
      environment: json['environment'] as String? ?? '',
      database: json['database'] as String? ?? 'unknown',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? ''),
    );
  }
}
