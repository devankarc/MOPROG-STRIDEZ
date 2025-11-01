import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/activity_data.dart';
import 'ml_service.dart';
import 'sensor_service.dart';

/// Main service untuk tracking aktivitas dengan ML
class ActivityTracker {
  final MLService _mlService = MLService();
  final SensorService _sensorService = SensorService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Tracking state
  bool _isTracking = false;
  DateTime? _startTime;
  Position? _lastPosition;
  String _currentActivity = 'idle';

  // Tracking data
  double _totalDistance = 0.0; // meter
  int _totalDuration = 0; // detik
  int _calories = 0;
  final List<RoutePoint> _routePoints = [];

  // Statistics
  int _runningCount = 0;
  int _walkingCount = 0;

  // Timers
  Timer? _durationTimer;
  Timer? _gpsTimer;

  // Stream controller untuk real-time updates
  final _trackingController = StreamController<TrackingStatus>.broadcast();
  Stream<TrackingStatus> get trackingStream => _trackingController.stream;

  // Singleton pattern
  static final ActivityTracker _instance = ActivityTracker._internal();
  factory ActivityTracker() => _instance;
  ActivityTracker._internal();

  /// Initialize services
  Future<void> initialize() async {
    print('🚀 Initializing Activity Tracker...');

    // Initialize ML Service
    await _mlService.initialize();

    // Setup sensor callback
    _sensorService.onNewSensorData = _onNewSensorData;

    print('✅ Activity Tracker initialized!');
  }

  /// Start tracking
  Future<void> startTracking() async {
    if (_isTracking) return;

    print('▶️ Starting activity tracking...');

    // Check permissions
    final hasPermission = await _checkPermissions();
    if (!hasPermission) {
      throw Exception('Location permission denied');
    }

    // Reset tracking data
    _resetTrackingData();

    // Start tracking
    _isTracking = true;
    _startTime = DateTime.now();

    // Start sensors
    _sensorService.startListening();

    // Start duration timer (update every second)
    _durationTimer = Timer.periodic(Duration(seconds: 1), (_) {
      _totalDuration++;
      _updateCalories();
      _emitTrackingUpdate();
    });

    // Start GPS tracking (update every 5 seconds)
    _gpsTimer = Timer.periodic(Duration(seconds: 5), (_) {
      _updateGPSPosition();
    });

    // Get initial position
    await _updateGPSPosition();

    print('✅ Tracking started!');
  }

  /// Stop tracking
  Future<ActivityData?> stopTracking() async {
    if (!_isTracking) return null;

    print('⏸️ Stopping activity tracking...');

    _isTracking = false;

    // Stop timers
    _durationTimer?.cancel();
    _gpsTimer?.cancel();

    // Stop sensors
    _sensorService.stopListening();

    // Create activity data
    final activityData = ActivityData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _startTime!,
      endTime: DateTime.now(),
      totalDistance: _totalDistance,
      totalDuration: _totalDuration,
      averageSpeed: _totalDuration > 0 ? _totalDistance / _totalDuration : 0,
      calories: _calories,
      activityType: _getDominantActivity(),
      routePoints: List.from(_routePoints),
      statistics: {
        'running_percentage': _runningCount > 0
            ? (_runningCount / (_runningCount + _walkingCount) * 100)
                  .toStringAsFixed(1)
            : '0.0',
        'walking_percentage': _walkingCount > 0
            ? (_walkingCount / (_runningCount + _walkingCount) * 100)
                  .toStringAsFixed(1)
            : '0.0',
        'total_samples': _runningCount + _walkingCount,
      },
    );

    // Save to Firebase
    await _saveToFirebase(activityData);

    print('✅ Tracking stopped!');
    return activityData;
  }

  /// Callback when new sensor data is available
  void _onNewSensorData(List<double> features) {
    if (!_isTracking) return;

    try {
      // Predict activity using ML
      final predictedActivity = _mlService.predictActivity(features);

      // Update current activity
      if (_currentActivity != predictedActivity) {
        _currentActivity = predictedActivity;
        print('🔄 Activity changed to: $_currentActivity');
      }

      // Update statistics
      if (predictedActivity == 'running') {
        _runningCount++;
      } else {
        _walkingCount++;
      }

      _emitTrackingUpdate();
    } catch (e) {
      print('❌ Error processing sensor data: $e');
    }
  }

  /// Update GPS position and calculate distance
  Future<void> _updateGPSPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Calculate distance from last position
      if (_lastPosition != null) {
        final distance = Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );

        // Only add if distance is significant (> 5 meters)
        if (distance > 5) {
          _totalDistance += distance;

          // Add route point
          _routePoints.add(
            RoutePoint(
              latitude: position.latitude,
              longitude: position.longitude,
              timestamp: DateTime.now(),
              activityType: _currentActivity,
            ),
          );

          print(
            '📍 Position updated. Distance: ${distance.toStringAsFixed(2)}m',
          );
        }
      } else {
        // First position
        _routePoints.add(
          RoutePoint(
            latitude: position.latitude,
            longitude: position.longitude,
            timestamp: DateTime.now(),
            activityType: _currentActivity,
          ),
        );
      }

      _lastPosition = position;
      _emitTrackingUpdate();
    } catch (e) {
      print('❌ Error updating GPS: $e');
    }
  }

  /// Calculate calories burned
  void _updateCalories() {
    // Simplified calculation (can be improved)
    // Running: ~10 cal/min, Walking: ~5 cal/min
    final runningMinutes = (_runningCount * 5) / 60; // 5 sec per sample
    final walkingMinutes = (_walkingCount * 5) / 60;

    _calories = (runningMinutes * 10 + walkingMinutes * 5).round();
  }

  /// Get dominant activity
  String _getDominantActivity() {
    if (_runningCount > _walkingCount) {
      return 'running';
    } else {
      return 'walking';
    }
  }

  /// Emit tracking update to stream
  void _emitTrackingUpdate() {
    final status = TrackingStatus(
      isTracking: _isTracking,
      currentActivity: _currentActivity,
      currentSpeed: _lastPosition?.speed ?? 0.0,
      currentDistance: _totalDistance,
      duration: _totalDuration,
      calories: _calories,
      currentLocation: _lastPosition != null
          ? LatLng(_lastPosition!.latitude, _lastPosition!.longitude)
          : null,
    );

    _trackingController.add(status);
  }

  /// Save activity to Firebase
  Future<void> _saveToFirebase(ActivityData data) async {
    try {
      print('💾 Saving to Firebase...');

      await _firestore.collection('activities').doc(data.id).set(data.toMap());

      print('✅ Saved to Firebase!');
    } catch (e) {
      print('❌ Error saving to Firebase: $e');
    }
  }

  /// Check and request permissions
  Future<bool> _checkPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('❌ Location services are disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('❌ Location permissions are denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('❌ Location permissions are permanently denied');
      return false;
    }

    return true;
  }

  /// Reset tracking data
  void _resetTrackingData() {
    _totalDistance = 0.0;
    _totalDuration = 0;
    _calories = 0;
    _currentActivity = 'idle';
    _runningCount = 0;
    _walkingCount = 0;
    _routePoints.clear();
    _lastPosition = null;
  }

  /// Dispose resources
  void dispose() {
    _durationTimer?.cancel();
    _gpsTimer?.cancel();
    _sensorService.stopListening();
    _trackingController.close();
  }

  // Getters
  bool get isTracking => _isTracking;
  String get currentActivity => _currentActivity;
  double get totalDistance => _totalDistance;
  int get duration => _totalDuration;
  int get calories => _calories;
}
