import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

/// Service sederhana untuk mengambil data sensor
class SensorService {
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;

  // Latest sensor values
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;

  // Callback untuk data baru (opsional)
  Function(List<double>)? onNewSensorData;

  bool _isListening = false;

  bool get isListening => _isListening;

  /// Start listening to sensors
  void startListening() {
    if (_isListening) return;

    print('🎧 Starting sensor listening...');

    _accelerometerSubscription = accelerometerEvents.listen((event) {
      _accelX = event.x;
      _accelY = event.y;
      _accelZ = event.z;
      _notifyData();
    });

    _gyroscopeSubscription = gyroscopeEvents.listen((event) {
      _gyroX = event.x;
      _gyroY = event.y;
      _gyroZ = event.z;
      _notifyData();
    });

    _isListening = true;
  }

  void _notifyData() {
    if (onNewSensorData != null) {
      onNewSensorData!(getCurrentReadings());
    }
  }

  /// Get current sensor readings [ax, ay, az, gx, gy, gz]
  List<double> getCurrentReadings() {
    return [_accelX, _accelY, _accelZ, _gyroX, _gyroY, _gyroZ];
  }

  /// Stop listening
  void stopListening() {
    _accelerometerSubscription?.cancel();
    _gyroscopeSubscription?.cancel();
    _isListening = false;
    print('🛑 Sensor listening stopped');
  }

  void dispose() {
    stopListening();
  }
}
