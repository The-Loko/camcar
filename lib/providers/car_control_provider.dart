import 'package:flutter/foundation.dart';
import '../services/gyroscope_service.dart';
import '../services/connection_service.dart';
import '../models/control_data.dart';
import '../models/bluetooth_device.dart';
import '../models/wifi_network.dart';
import '../models/sensor_data.dart';
import '../utils/logger.dart';

class CarControlProvider with ChangeNotifier {
  final GyroscopeService _gyroscopeService = GyroscopeService();
  final ConnectionService _connectionService = ConnectionService();

  bool get isControlActive => _gyroscopeService.isActive;
  double get sensitivity => _gyroscopeService.sensitivity;
  ConnectionType get connectionType => _connectionService.connectionType;
  ConnectionStatus get connectionStatus => _connectionService.connectionStatus;
  String get errorMessage => _connectionService.errorMessage;
  
  ControlData? _lastControlData;
  ControlData? get lastControlData => _lastControlData;
  SensorData _sensorData = SensorData(distance: 0, temperature: 0, humidity: 0);
  SensorData get sensorData => _sensorData;

  bool _isPowerOn = false;
  bool get isPowerOn => _isPowerOn;

  bool _isAutoMode = false;
  bool get isAutoMode => _isAutoMode;

  String _cameraUrl = '';
  String get cameraUrl => _cameraUrl;
  set cameraUrl(String url) {
    _cameraUrl = url;
    notifyListeners();
  }

  void toggleControl() {
    if (isControlActive) {
      stopControl();
    } else {
      startControl();
    }
  }

  void startControl() {
    if (_connectionService.connectionStatus != ConnectionStatus.connected) {
      // Can't start if not connected
      return;
    }

    _gyroscopeService.start(onDataReceived: _handleGyroscopeData);
    notifyListeners();
  }

  void stopControl() {
    _gyroscopeService.stop();
    notifyListeners();
  }

  void setSensitivity(double value) {
    _gyroscopeService.setSensitivity(value);
    notifyListeners();
  }

  Future<bool> connectWifi(String ipAddress, int port) async {
    try {
      final result = await _connectionService.connectWifi(ipAddress, port);
      if (result) {
        // Validate the camera URL is accessible
        cameraUrl = 'http://$ipAddress:$port/stream';
        Logger.log('Camera URL set to: $cameraUrl');
      } else {
        Logger.log('Failed to connect to WiFi camera');
      }
      notifyListeners();
      return result;
    } catch (e) {
      Logger.log('WiFi connection error in provider: $e');
      notifyListeners();
      return false;
    }
  }

  // Send joystick move
  void sendJoystick(double x, double y) {
    _connectionService.sendJoystickData({'x': x, 'y': y});
  }

  // Send joystick data (new method name for consistency)
  void sendJoystickData(double x, double y) {
    _connectionService.sendJoystickData({'x': x, 'y': y});
  }

  // Send power command
  void sendPowerCommand(bool isOn) {
    _isPowerOn = isOn;
    _connectionService.sendJoystickData({'cmd': 'power', 'value': isOn});
    notifyListeners();
  }

  // Send mode command
  void sendModeCommand(String mode) {
    _isAutoMode = mode == 'auto';
    _connectionService.sendJoystickData({'cmd': 'mode', 'value': mode});
    notifyListeners();
  }  void _handleSensorJson(Map<String, dynamic> json) {
    try {
      // Log the raw data received
      Logger.log('Processing sensor data: $json');
      
      // Extract sensor values with proper error handling
      double? distance, temperature, humidity;
      
      // Extract distance - could be in cm or m
      if (json.containsKey('distance')) {
        try {
          distance = double.tryParse(json['distance'].toString()) ?? _sensorData.distance;
          // If distance is unreasonably large or small, ignore it
          if (distance < 0 || distance > 1000) {
            distance = _sensorData.distance;
          }
        } catch (e) {
          Logger.log('Error parsing distance: $e');
        }
      }
      
      // Extract temperature - could be under 'temp' or 'temperature'
      if (json.containsKey('temp')) {
        try {
          temperature = double.tryParse(json['temp'].toString()) ?? _sensorData.temperature;
        } catch (e) {
          Logger.log('Error parsing temp: $e');
        }
      } else if (json.containsKey('temperature')) {
        try {
          temperature = double.tryParse(json['temperature'].toString()) ?? _sensorData.temperature;
        } catch (e) {
          Logger.log('Error parsing temperature: $e');
        }
      }
      
      // Extract humidity
      if (json.containsKey('humidity')) {
        try {
          humidity = double.tryParse(json['humidity'].toString()) ?? _sensorData.humidity;
          // If humidity is out of range, ignore it
          if (humidity < 0 || humidity > 100) {
            humidity = _sensorData.humidity;
          }
        } catch (e) {
          Logger.log('Error parsing humidity: $e');
        }
      }
      
      // Update sensor data
      _sensorData = SensorData(
        distance: distance ?? _sensorData.distance,
        temperature: temperature ?? _sensorData.temperature,
        humidity: humidity ?? _sensorData.humidity,
      );
      
      // Log the updated sensor data
      Logger.log('Updated sensor data: distance=${_sensorData.distance}cm, '
          'temp=${_sensorData.temperature}°C, '
          'humidity=${_sensorData.humidity}%');
      
      notifyListeners();
    } catch (e) {
      Logger.log('Error processing sensor data: $e');
    }
  }

  Future<bool> connectBluetooth(String address) async {
    try {
      Logger.log('Attempting Bluetooth connection to: $address');
      final result = await _connectionService.connectBluetooth(address);
      if (result) {
        Logger.log('Bluetooth connected successfully, setting up sensor listener');
        _connectionService.listenForSensorData(_handleSensorJson);
      } else {
        Logger.log('Bluetooth connection failed');
      }
      notifyListeners();
      return result;
    } catch (e) {
      Logger.log('Bluetooth connection error in provider: $e');
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connectionService.disconnect();
    notifyListeners();
  }
  Future<List<BluetoothDevice>> scanBluetoothDevices() async {
    try {
      Logger.log('Starting Bluetooth device scan from provider');
      final devices = await _connectionService.scanBluetoothDevices();
      Logger.log('Scan completed, found ${devices.length} devices');
      return devices;
    } catch (e) {
      Logger.log('Bluetooth scan error in provider: $e');
      return [];
    }
  }

  Future<List<WiFiNetwork>> scanWifiNetworks() {
    return _connectionService.scanWifiNetworks();
  }

  void _handleGyroscopeData(ControlData data) {
    _lastControlData = data;
    _connectionService.sendControlData(data);
    notifyListeners();
  }

  void togglePower() {
    _isPowerOn = !_isPowerOn;
    _connectionService.sendJoystickData({'cmd': 'power', 'value': _isPowerOn});
    notifyListeners();
  }

  void toggleMode() {
    _isAutoMode = !_isAutoMode;
    _connectionService.sendJoystickData({'cmd': 'mode', 'value': _isAutoMode});
    notifyListeners();
  }

  @override
  void dispose() {
    _gyroscopeService.dispose();
    _connectionService.disconnect();
    super.dispose();
  }
}
