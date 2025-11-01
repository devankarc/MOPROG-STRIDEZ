import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'ml_service.dart';
import 'sensor_service.dart';

/// Tracker untuk mendeteksi aktivitas run/walk secara real-time
class ActivityTracker {
  final MLService _mlService = MLService();
  final SensorService _sensorService = SensorService();

  Timer? _predictionTimer;
  bool _isTracking = false;

  // Current activity state
  String _currentActivity = 'walking';
  double _confidence = 0.0;

  // Callbacks
  Function(String activity, double confidence)? onActivityChanged;
  Function(String activity)? onActivityUpdate;

  bool get isTracking => _isTracking;
  String get currentActivity => _currentActivity;
  double get confidence => _confidence;

  /// Initialize ML model
  Future<void> initialize() async {
    await _mlService.initialize();
    print('✅ ActivityTracker initialized');
  }

  /// Start tracking activity
  Future<void> startTracking() async {
    if (_isTracking) return;

    if (!_mlService.isInitialized) {
      await initialize();
    }

    _isTracking = true;
    print('▶️ Activity tracking started');

    // Start sensor service
    _sensorService.startListening();

    // Start periodic prediction (every 1 second)
    _predictionTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _performPrediction();
    });
  }

  /// Perform ML prediction
  void _performPrediction() {
    if (!_isTracking) return;

    try {
      // Get current sensor data
      final sensorData = _sensorService.getCurrentReadings();

      // Predict activity
      final predictedActivity = _mlService.predictActivity(sensorData);

      // Check if activity changed
      if (predictedActivity != _currentActivity) {
        final oldActivity = _currentActivity;
        _currentActivity = predictedActivity;

        print('🔄 Activity changed: $oldActivity → $predictedActivity');

        // Notify callback
        if (onActivityChanged != null) {
          onActivityChanged!(predictedActivity, _confidence);
        }
      }

      // Always notify update
      if (onActivityUpdate != null) {
        onActivityUpdate!(predictedActivity);
      }
    } catch (e) {
      print('❌ Prediction error: $e');
    }
  }

  /// Stop tracking
  void stopTracking() {
    if (!_isTracking) return;

    _isTracking = false;
    _predictionTimer?.cancel();
    _sensorService.stopListening();

    print('⏸️ Activity tracking stopped');
  }

  /// Reset to initial state
  void reset() {
    _currentActivity = 'walking';
    _confidence = 0.0;
  }

  void dispose() {
    stopTracking();
    _mlService.dispose();
    _sensorService.dispose();
  }
}
