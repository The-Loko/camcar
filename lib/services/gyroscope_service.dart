import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import '../models/control_data.dart';

class GyroscopeService {
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  Function(ControlData)? _onDataReceived;
  bool _isActive = false;
  double _sensitivity = 1.0;

  bool get isActive => _isActive;
  double get sensitivity => _sensitivity;

  void setSensitivity(double value) {
    _sensitivity = value;
  }

  void start({required Function(ControlData) onDataReceived}) {
    if (_isActive) return;

    _onDataReceived = onDataReceived;
    _gyroscopeSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      final controlData = ControlData(
        x: event.x,
        y: event.y,
        z: event.z,
        sensitivity: _sensitivity,
      );
      _onDataReceived?.call(controlData);
    });
    
    _isActive = true;
  }

  void stop() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _onDataReceived = null;
    _isActive = false;
  }

  void dispose() {
    stop();
  }
}
