import 'package:latlong2/latlong.dart';

class FloodLine {
  final String id;
  final List<LatLng> points;
  final DateTime timestamp;
  final String reporterName;
  final String description;
  final String depth;

  FloodLine({
    required this.id,
    required this.points,
    required this.timestamp,
    required this.reporterName,
    this.description = '',
    this.depth = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'points': points.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'timestamp': timestamp.toIso8601String(),
    'reporterName': reporterName,
    'description': description,
    'depth': depth,
  };

  factory FloodLine.fromJson(Map<String, dynamic> json) => FloodLine(
    id: json['id'],
    points: (json['points'] as List).map((p) => LatLng(p['lat'], p['lng'])).toList(),
    timestamp: DateTime.parse(json['timestamp']),
    reporterName: json['reporterName'],
    description: json['description'] ?? '',
    depth: json['depth'] ?? '',
  );
}

