// lib/models/report_model.dart

class ReportModel {
  final String id;
  final String? imageLink;
  final double lat;
  final double long;
  final int intensity;
  final String? reporterName;
  final String status;
  final DateTime? createdAt;
  final String? userId;

  ReportModel({
    required this.id,
    this.imageLink,
    required this.lat,
    required this.long,
    required this.intensity,
    this.reporterName,
    this.status = 'pending',
    this.createdAt,
    this.userId,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id']?.toString() ?? '',
      imageLink: json['image_link'],
      lat: (json['lat'] as num?)?.toDouble() ?? 0,
      long: (json['long'] as num?)?.toDouble() ?? 0,
      intensity: (json['intensity'] as num?)?.toInt() ?? 1,
      reporterName: json['name'] ?? json['profiles']?['full_name'],
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      userId: json['user_id'],
    );
  }

  String get intensityLabel {
    switch (intensity) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Unknown';
    }
  }

  String get statusLabel {
    switch (status.toLowerCase()) {
      case 'success':
        return 'Collected';
      case 'pending':
        return 'Pending';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }
}
