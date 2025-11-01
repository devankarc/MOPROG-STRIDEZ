import 'package:flutter/material.dart';
import 'services/activity_tracker.dart';

/// Halaman untuk testing ML model detection
class MLTestPage extends StatefulWidget {
  const MLTestPage({super.key});

  @override
  State<MLTestPage> createState() => _MLTestPageState();
}

class _MLTestPageState extends State<MLTestPage> {
  final ActivityTracker _tracker = ActivityTracker();

  String _currentActivity = 'Belum Mulai';
  bool _isTracking = false;
  bool _isInitialized = false;

  List<String> _activityLog = [];

  @override
  void initState() {
    super.initState();
    _initializeTracker();
  }

  Future<void> _initializeTracker() async {
    try {
      await _tracker.initialize();

      // Setup callbacks
      _tracker.onActivityChanged = (activity, confidence) {
        if (mounted) {
          setState(() {
            _activityLog.insert(
              0,
              '${DateTime.now().toString().substring(11, 19)} - Berubah ke: ${activity.toUpperCase()}',
            );
            if (_activityLog.length > 10) {
              _activityLog.removeLast();
            }
          });

          // Show snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aktivitas: ${activity.toUpperCase()}'),
              duration: Duration(seconds: 1),
              backgroundColor: activity == 'running'
                  ? Colors.orange
                  : Colors.blue,
            ),
          );
        }
      };

      _tracker.onActivityUpdate = (activity) {
        if (mounted) {
          setState(() {
            _currentActivity = activity;
          });
        }
      };

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _toggleTracking() {
    if (_isTracking) {
      _tracker.stopTracking();
    } else {
      _tracker.startTracking();
    }

    setState(() {
      _isTracking = !_isTracking;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ML Activity Detection Test'),
        backgroundColor: Colors.deepOrange,
      ),
      body: _isInitialized ? _buildContent() : _buildLoading(),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Memuat ML Model...'),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Current Activity Display
          Card(
            elevation: 8,
            color: _getActivityColor(_currentActivity),
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(
                    _getActivityIcon(_currentActivity),
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentActivity.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Control Button
          ElevatedButton.icon(
            onPressed: _toggleTracking,
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            label: Text(
              _isTracking ? 'Stop Detection' : 'Start Detection',
              style: const TextStyle(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTracking ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  '📱 Cara Menggunakan:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Text('1. Klik "Start Detection"'),
                Text('2. Mulai berjalan atau berlari'),
                Text('3. Aplikasi akan mendeteksi aktivitas Anda'),
                Text('4. Lihat perubahan aktivitas di log'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Activity Log
          const Text(
            'Log Aktivitas:',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: _activityLog.isEmpty
                  ? const Center(
                      child: Text(
                        'Belum ada aktivitas',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _activityLog.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.circle,
                            size: 8,
                            color: Colors.grey[600],
                          ),
                          title: Text(
                            _activityLog[index],
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getActivityIcon(String activity) {
    switch (activity.toLowerCase()) {
      case 'walking':
        return Icons.directions_walk;
      case 'running':
        return Icons.directions_run;
      default:
        return Icons.help_outline;
    }
  }

  Color _getActivityColor(String activity) {
    switch (activity.toLowerCase()) {
      case 'walking':
        return Colors.blue;
      case 'running':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _tracker.dispose();
    super.dispose();
  }
}
