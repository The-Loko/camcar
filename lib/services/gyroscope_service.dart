import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../utils/logger.dart';

class GyroscopeService {
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Function(double, double, double)? _onDataReceived;
  bool _isActive = false;
  double _sensitivity = 1.0;

  bool get isActive => _isActive;
  double get sensitivity => _sensitivity;

  void setSensitivity(double value) {
    _sensitivity = value;
  }

  // New simplified method name to match our provider
  void startListening(Function(double, double, double) onDataReceived) {
    if (_isActive) return;

    Logger.log('Starting gyroscope listening...');
    _onDataReceived = onDataReceived;
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      // Apply sensitivity and pass raw x, y, z values
      double x = event.x * _sensitivity;
      double y = event.y * _sensitivity;
      double z = event.z * _sensitivity;
      
      _onDataReceived?.call(x, y, z);
    });
    
    _isActive = true;
  }

  void stopListening() {
    Logger.log('Stopping gyroscope listening...');
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _onDataReceived = null;
    _isActive = false;
  }

  // Keep the old method for backward compatibility
  void start({required Function(double, double, double) onDataReceived}) {
    startListening(onDataReceived);
  }

  void stop() {
    stopListening();
  }

  void dispose() {
    stop();
  }
}
