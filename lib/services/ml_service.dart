import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Service untuk handle Machine Learning prediction
class MLService {
  Interpreter? _interpreter;
  Map<String, dynamic>? _scalerParams;
  bool _isInitialized = false;

  // Singleton pattern
  static final MLService _instance = MLService._internal();
  factory MLService() => _instance;
  MLService._internal();

  /// Initialize ML model
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      print('🤖 Initializing ML Service...');

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(
        'assets/ml_model/run_walk_model.tflite',
      );
      print('✅ Model loaded successfully');

      // Load scaler parameters
      final scalerJson = await rootBundle.loadString(
        'assets/ml_model/scaler_params.json',
      );
      _scalerParams = json.decode(scalerJson);
      print('✅ Scaler parameters loaded');

      _isInitialized = true;
      print('🎉 ML Service initialized!');
    } catch (e) {
      print('❌ Error initializing ML Service: $e');
      rethrow;
    }
  }

  /// Predict activity from sensor data
  /// Returns: 'walking' or 'running'
  String predictActivity(List<double> sensorData) {
    if (!_isInitialized) {
      throw Exception('ML Service not initialized. Call initialize() first.');
    }

    try {
      // Normalize sensor data
      final normalizedData = _normalizeSensorData(sensorData);

      // Prepare input
      final input = [normalizedData];

      // Prepare output
      var output = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _interpreter!.run(input, output);

      // Get prediction (0 = walking, 1 = running)
      final prediction = output[0][0];

      // Threshold 0.5
      final activityType = prediction > 0.5 ? 'running' : 'walking';

      print(
        '🔮 Prediction: $activityType (confidence: ${prediction.toStringAsFixed(3)})',
      );

      return activityType;
    } catch (e) {
      print('❌ Error predicting activity: $e');
      return 'walking'; // default fallback
    }
  }

  /// Normalize sensor data using scaler parameters
  List<double> _normalizeSensorData(List<double> data) {
    if (_scalerParams == null) {
      throw Exception('Scaler parameters not loaded');
    }

    final mean = List<double>.from(_scalerParams!['mean']);
    final scale = List<double>.from(_scalerParams!['scale']);

    if (data.length != mean.length) {
      throw Exception(
        'Data length mismatch. Expected ${mean.length}, got ${data.length}',
      );
    }

    // Normalize: (x - mean) / scale
    final normalized = <double>[];
    for (int i = 0; i < data.length; i++) {
      normalized.add((data[i] - mean[i]) / scale[i]);
    }

    return normalized;
  }

  /// Get required feature names from scaler
  List<String> getFeatureNames() {
    if (_scalerParams == null) return [];
    return List<String>.from(_scalerParams!['feature_names']);
  }

  /// Get number of features required
  int getNumberOfFeatures() {
    return _scalerParams?['n_features'] ?? 0;
  }

  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _scalerParams = null;
    _isInitialized = false;
    print('🗑️ ML Service disposed');
  }

  bool get isInitialized => _isInitialized;
}
