import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class MLService {
  Interpreter? _interpreter;
  Map<String, dynamic>? _scalerParams;
  bool _isInitialized = false;

  /// Initialize ML model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🤖 Initializing ML Service...');

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/ml_model/run_walk_model.tflite',
      );
      print('✅ Model loaded');

      // Load scaler parameters
      final scalerJson = await rootBundle.loadString(
        'assets/ml_model/scaler_params.json',
      );
      _scalerParams = json.decode(scalerJson);
      print('✅ Scaler loaded');

      _isInitialized = true;
    } catch (e) {
      print('❌ Error initializing ML: $e');
      rethrow;
    }
  }

  /// Predict activity from raw sensor data
  /// Input: [ax, ay, az, gx, gy, gz]
  /// Returns: 'walking' or 'running'
  String predictActivity(List<double> sensorData) {
    if (!_isInitialized || _interpreter == null) {
      print('⚠️ ML not initialized');
      return 'walking'; // default
    }

    try {
      // Normalize data
      final normalized = _normalizeSensorData(sensorData);

      // Prepare input [1, 6]
      final input = [normalized];

      // Prepare output [1, 1]
      var output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _interpreter!.run(input, output);

      // Get prediction (0 = walking, 1 = running)
      final prediction = output[0][0];
      final activity = prediction > 0.5 ? 'running' : 'walking';

      print(
        '🔮 Predicted: $activity (${(prediction * 100).toStringAsFixed(1)}%)',
      );

      return activity;
    } catch (e) {
      print('❌ Prediction error: $e');
      return 'walking';
    }
  }

  /// Normalize sensor data using scaler
  List<double> _normalizeSensorData(List<double> data) {
    if (_scalerParams == null) return data;

    final mean = List<double>.from(_scalerParams!['mean']);
    final scale = List<double>.from(_scalerParams!['scale']);

    final normalized = <double>[];
    for (int i = 0; i < data.length; i++) {
      normalized.add((data[i] - mean[i]) / scale[i]);
    }

    return normalized;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }

  bool get isInitialized => _isInitialized;
}
