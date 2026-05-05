import 'package:latlong2/latlong.dart';

enum HazardType { pothole, accident, construction, other }

class Hazard {
  final String id;
  final LatLng location;
  final HazardType type;
  final DateTime timestamp;
  final String reporterName;
  final String description;

  Hazard({
    required this.id,
    required this.location,
    required this.type,
    required this.timestamp,
    required this.reporterName,
    this.description = '',
  });


  String get typeString => type.toString().split('.').last;

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': location.latitude,
    'lng': location.longitude,
    'type': type.index,
    'timestamp': timestamp.toIso8601String(),
    'reporterName': reporterName,
    'description': description,
  };

  factory Hazard.fromJson(Map<String, dynamic> json) => Hazard(
    id: json['id'],
    location: LatLng(json['lat'], json['lng']),
    type: HazardType.values[json['type']],
    timestamp: DateTime.parse(json['timestamp']),
    reporterName: json['reporterName'],
    description: json['description'] ?? '',
  );
}


