import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// Service untuk handle sensor data (accelerometer & gyroscope)
class SensorService {
  // Stream subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Buffer untuk menyimpan sensor data
  final List<Map<String, double>> _sensorBuffer = [];
  final int _bufferSize = 100; // Sesuai dengan training data
  final int _samplingRate = 50; // Sample setiap 50ms

  // Latest sensor values
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;

  // Callback untuk new prediction
  Function(List<double>)? onNewSensorData;

  Timer? _samplingTimer;
  bool _isListening = false;

  // Singleton pattern
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  /// Start listening to sensors
  void startListening() {
    if (_isListening) return;

    print('🎧 Starting sensor listening...');

    // Listen to accelerometer
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _accelX = event.x;
      _accelY = event.y;
      _accelZ = event.z;
    });

    // Listen to gyroscope
    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      _gyroX = event.x;
      _gyroY = event.y;
      _gyroZ = event.z;
    });

    // Sampling timer - collect data every 50ms
    _samplingTimer = Timer.periodic(
      Duration(milliseconds: _samplingRate),
      (_) => _collectSensorSample(),
    );

    _isListening = true;
    print('✅ Sensor listening started');
  }

  /// Collect sensor sample and add to buffer
  void _collectSensorSample() {
    final sample = {
      'acceleration_x': _accelX,
      'acceleration_y': _accelY,
      'acceleration_z': _accelZ,
      'gyro_x': _gyroX,
      'gyro_y': _gyroY,
      'gyro_z': _gyroZ,
    };

    _sensorBuffer.add(sample);

    // Keep buffer size fixed
    if (_sensorBuffer.length > _bufferSize) {
      _sensorBuffer.removeAt(0);
    }

    // If buffer is full, process data for prediction
    if (_sensorBuffer.length == _bufferSize) {
      _processSensorData();
    }
  }

  /// Process sensor data for ML prediction
  void _processSensorData() {
    // Calculate features from buffer (statistical features)
    final features = _extractFeatures();

    // Call callback with features
    if (onNewSensorData != null) {
      onNewSensorData!(features);
    }
  }

  /// Extract features from sensor buffer
  /// Returns list of features matching training data format
  List<double> _extractFeatures() {
    // Extract each sensor axis
    final accelX = _sensorBuffer.map((s) => s['acceleration_x']!).toList();
    final accelY = _sensorBuffer.map((s) => s['acceleration_y']!).toList();
    final accelZ = _sensorBuffer.map((s) => s['acceleration_z']!).toList();
    final gyroX = _sensorBuffer.map((s) => s['gyro_x']!).toList();
    final gyroY = _sensorBuffer.map((s) => s['gyro_y']!).toList();
    final gyroZ = _sensorBuffer.map((s) => s['gyro_z']!).toList();

    // Calculate statistical features
    final features = <double>[];

    // Mean features
    features.add(_calculateMean(accelX));
    features.add(_calculateMean(accelY));
    features.add(_calculateMean(accelZ));
    features.add(_calculateMean(gyroX));
    features.add(_calculateMean(gyroY));
    features.add(_calculateMean(gyroZ));

    // Standard deviation features
    features.add(_calculateStd(accelX));
    features.add(_calculateStd(accelY));
    features.add(_calculateStd(accelZ));
    features.add(_calculateStd(gyroX));
    features.add(_calculateStd(gyroY));
    features.add(_calculateStd(gyroZ));

    // Magnitude features
    final accelMagnitude = _calculateMagnitude(accelX, accelY, accelZ);
    final gyroMagnitude = _calculateMagnitude(gyroX, gyroY, gyroZ);
    features.add(_calculateMean(accelMagnitude));
    features.add(_calculateStd(accelMagnitude));
    features.add(_calculateMean(gyroMagnitude));
    features.add(_calculateStd(gyroMagnitude));

    return features;
  }

  /// Calculate mean
  double _calculateMean(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  /// Calculate standard deviation
  double _calculateStd(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = _calculateMean(values);
    final variance =
        values.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
        values.length;
    return variance < 0 ? 0.0 : variance.sqrt();
  }

  /// Calculate magnitude from 3-axis data
  List<double> _calculateMagnitude(
    List<double> x,
    List<double> y,
    List<double> z,
  ) {
    final magnitude = <double>[];
    for (int i = 0; i < x.length; i++) {
      final mag = (x[i] * x[i] + y[i] * y[i] + z[i] * z[i]).sqrt();
      magnitude.add(mag);
    }
    return magnitude;
  }

  /// Stop listening to sensors
  void stopListening() {
    if (!_isListening) return;

    print('🛑 Stopping sensor listening...');

    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _samplingTimer?.cancel();

    _accelerometerSubscription = null;
    _gyroscopeSubscription = null;
    _samplingTimer = null;

    _sensorBuffer.clear();
    _isListening = false;

    print('✅ Sensor listening stopped');
  }

  /// Reset buffer
  void resetBuffer() {
    _sensorBuffer.clear();
    print('🔄 Sensor buffer reset');
  }

  bool get isListening => _isListening;
  int get bufferSize => _sensorBuffer.length;
}

// Extension untuk sqrt
extension DoubleExtension on double {
  double sqrt() => this < 0 ? 0.0 : this.squareRoot();
  double squareRoot() => this < 0 ? 0.0 : this.squareRootPositive();
  double squareRootPositive() {
    if (this == 0) return 0;
    double x = this;
    double y = 1;
    double e = 0.000001;
    while (x - y > e) {
      x = (x + y) / 2;
      y = this / x;
    }
    return x;
  }
}
