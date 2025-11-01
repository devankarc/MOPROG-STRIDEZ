import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

/// Model untuk menyimpan data aktivitas lari/jalan
class ActivityData {
  final String id;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistance; // dalam meter
  final int totalDuration; // dalam detik
  final double averageSpeed; // dalam m/s
  final int calories;
  final String activityType; // 'running' atau 'walking'
  final List<RoutePoint> routePoints;
  final Map<String, dynamic> statistics;

  ActivityData({
    required this.id,
    required this.startTime,
    this.endTime,
    required this.totalDistance,
    required this.totalDuration,
    required this.averageSpeed,
    required this.calories,
    required this.activityType,
    required this.routePoints,
    required this.statistics,
  });

  // Convert to Map untuk Firebase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': endTime != null ? Timestamp.fromDate(endTime!) : null,
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'averageSpeed': averageSpeed,
      'calories': calories,
      'activityType': activityType,
      'routePoints': routePoints.map((point) => point.toMap()).toList(),
      'statistics': statistics,
    };
  }

  // Create from Firebase Map
  factory ActivityData.fromMap(Map<String, dynamic> map) {
    return ActivityData(
      id: map['id'] ?? '',
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: map['endTime'] != null
          ? (map['endTime'] as Timestamp).toDate()
          : null,
      totalDistance: map['totalDistance']?.toDouble() ?? 0.0,
      totalDuration: map['totalDuration'] ?? 0,
      averageSpeed: map['averageSpeed']?.toDouble() ?? 0.0,
      calories: map['calories'] ?? 0,
      activityType: map['activityType'] ?? 'walking',
      routePoints:
          (map['routePoints'] as List<dynamic>?)
              ?.map((point) => RoutePoint.fromMap(point))
              .toList() ??
          [],
      statistics: map['statistics'] ?? {},
    );
  }

  // Helper methods
  String get distanceInKm => (totalDistance / 1000).toStringAsFixed(2);
  String get durationFormatted {
    final hours = totalDuration ~/ 3600;
    final minutes = (totalDuration % 3600) ~/ 60;
    final seconds = totalDuration % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  String get speedInKmh => (averageSpeed * 3.6).toStringAsFixed(2);
  String get pacePerKm {
    if (averageSpeed == 0) return '--:--';
    final paceInSeconds = 1000 / averageSpeed; // detik per km
    final minutes = paceInSeconds ~/ 60;
    final seconds = (paceInSeconds % 60).round();
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Model untuk menyimpan titik koordinat route
class RoutePoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final String activityType; // 'running' atau 'walking' pada saat itu

  RoutePoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    required this.activityType,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': Timestamp.fromDate(timestamp),
      'activityType': activityType,
    };
  }

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      activityType: map['activityType'] ?? 'walking',
    );
  }
}

/// Model untuk real-time tracking status
class TrackingStatus {
  final bool isTracking;
  final String currentActivity; // 'running', 'walking', atau 'idle'
  final double currentSpeed; // m/s
  final double currentDistance; // meter
  final int duration; // detik
  final int calories;
  final LatLng? currentLocation;

  TrackingStatus({
    required this.isTracking,
    required this.currentActivity,
    required this.currentSpeed,
    required this.currentDistance,
    required this.duration,
    required this.calories,
    this.currentLocation,
  });

  TrackingStatus copyWith({
    bool? isTracking,
    String? currentActivity,
    double? currentSpeed,
    double? currentDistance,
    int? duration,
    int? calories,
    LatLng? currentLocation,
  }) {
    return TrackingStatus(
      isTracking: isTracking ?? this.isTracking,
      currentActivity: currentActivity ?? this.currentActivity,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      currentDistance: currentDistance ?? this.currentDistance,
      duration: duration ?? this.duration,
      calories: calories ?? this.calories,
      currentLocation: currentLocation ?? this.currentLocation,
    );
  }
}
