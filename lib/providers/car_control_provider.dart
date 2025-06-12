import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/connection_service.dart';
import '../services/gyroscope_service.dart';
import '../models/bluetooth_device.dart';
import '../models/sensor_data.dart';
import '../utils/logger.dart' as utils_logger;

enum ConnectionStatus { disconnected, connecting, connected, error }

class CarControlProvider with ChangeNotifier {
  // Connection status
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _errorMessage;
  String? _cameraUrl;
  
  // Car control states
  bool _isPowerOn = false;
  bool _isAutoMode = false;
  bool _isControlActive = false;
  double _sensitivity = 0.5;
  
  // Sensor data from ESP32
  SensorData _sensorData = SensorData();
  
  // Gyroscope service
  final GyroscopeService _gyroscopeService = GyroscopeService();
  
  // Bluetooth service instance
  final BluetoothService _bluetoothService = BluetoothService();
  // Getters
  ConnectionStatus get connectionStatus => _connectionStatus;
  String get errorMessage => _errorMessage ?? '';
  String get cameraUrl => _cameraUrl ?? '';
  SensorData get sensorData => _sensorData;
  bool get isConnected => _bluetoothService.isConnected;
  
  // Car control getters
  bool get isPowerOn => _isPowerOn;
  bool get isAutoMode => _isAutoMode;
  bool get isControlActive => _isControlActive;
  double get sensitivity => _sensitivity;

  // Set camera URL (no connection needed, just for streaming)
  set cameraUrl(String? url) {
    _cameraUrl = url;
    notifyListeners();
  }  // Scan for Bluetooth devices
  Future<List<BluetoothDevice>> scanBluetoothDevices() async {
    utils_logger.Logger.log('Starting Bluetooth device scan...');
    _setConnectionStatus(ConnectionStatus.connecting);
    
    try {
      // Check if Bluetooth is enabled
      bool isEnabled = await _bluetoothService.requestBluetoothEnable();
      if (!isEnabled) {
        utils_logger.Logger.log('Bluetooth not enabled, requesting enable...');
        bool enabled = await _bluetoothService.requestBluetoothEnable();
        if (!enabled) {
          throw Exception('Bluetooth must be enabled to scan for devices');
        }
      }

      List<BluetoothDevice> devices = await _bluetoothService.scanForDevices();
      utils_logger.Logger.log('Found ${devices.length} Bluetooth devices');
      
      _setConnectionStatus(ConnectionStatus.disconnected);
      return devices;
      
    } catch (e) {
      _setError('Bluetooth scan failed: $e');
      return [];
    }
  }

  // Connect to Bluetooth device
  Future<bool> connectBluetooth(String address) async {
    utils_logger.Logger.log('Connecting to Bluetooth device: $address');
    _setConnectionStatus(ConnectionStatus.connecting);
    
    try {
      // Set up sensor data callback before connecting
      _bluetoothService.setDataCallback((data) {
        try {
          final Map<String, dynamic> jsonData = json.decode(data) as Map<String, dynamic>;
          _handleSensorData(jsonData);
        } catch (e) {
          utils_logger.Logger.error('Error decoding sensor data: $e');
        }
      });

      bool connected = await _bluetoothService.connectToDevice(address);
      
      if (connected) {
        _setConnectionStatus(ConnectionStatus.connected);
        utils_logger.Logger.log('Successfully connected to Bluetooth device');
        
        // Send initial power on command
        await _bluetoothService.sendCommand('POWER:1');
        
        return true;
      } else {
        _setError('Failed to connect to Bluetooth device');
        return false;
      }
      
    } catch (e) {
      _setError('Bluetooth connection error: $e');
      return false;
    }
  }

  // Connect to ESP32-CAM WiFi
  Future<bool> connectCamera(String ipAddress, int port) async {
    utils_logger.Logger.log('Connecting to camera at $ipAddress:$port');
    _setConnectionStatus(ConnectionStatus.connecting);
    
    try {
      bool connected = await ConnectionService.testCameraConnection(ipAddress, port);
      
      if (connected) {
        _cameraUrl = ConnectionService.getMjpegStreamUrl();
        utils_logger.Logger.log('Successfully connected to camera: $_cameraUrl');
        notifyListeners();
        return true;
      } else {
        _setError('Failed to connect to camera: ${ConnectionService.errorMessage}');
        return false;
      }
      
    } catch (e) {
      _setError('Camera connection error: $e');
      return false;
    }
  }

  // Disconnect from camera
  void disconnectCamera() {
    ConnectionService.disconnect();
    utils_logger.Logger.log('Disconnected from camera');
    notifyListeners();
  }

  // Send joystick data
  Future<bool> sendJoystickData(double x, double y) async {
    if (!isConnected) {
      utils_logger.Logger.log('Cannot send joystick data: not connected');
      return false;
    }

    return await _bluetoothService.sendJoystickData(x, y);
  }

  // Send power command
  Future<bool> sendPowerCommand(bool enabled) async {
    if (!isConnected) {
      utils_logger.Logger.log('Cannot send power command: not connected');
      return false;
    }

    return await _bluetoothService.sendCommand('POWER:${enabled?1:0}');
  }

  // Send mode command
  Future<bool> sendModeCommand(bool autoMode) async {
    if (!isConnected) {
      utils_logger.Logger.log('Cannot send mode command: not connected');
      return false;
    }

    return await _bluetoothService.sendCommand('MODE:${autoMode?1:0}');
  }

  // Start gyroscope monitoring
  void startGyroscopeControl() {
    _gyroscopeService.startListening((x, y, z) {
      // Send gyroscope data as joystick input
      // Map gyroscope values to joystick range (-1.0 to 1.0)
      double joyX = x.clamp(-1.0, 1.0);
      double joyY = y.clamp(-1.0, 1.0);
      
      sendJoystickData(joyX, joyY);
    });
  }

  // Stop gyroscope monitoring
  void stopGyroscopeControl() {
    _gyroscopeService.stopListening();
  }

  // Disconnect
  Future<void> disconnect() async {
    utils_logger.Logger.log('Disconnecting from all services...');
    
    try {
      // Stop gyroscope
      stopGyroscopeControl();
      
      // Send power off command before disconnecting
      if (isConnected) {
        await _bluetoothService.sendCommand('POWER:0');
        await Future.delayed(const Duration(milliseconds: 100));
      }
        // Disconnect Bluetooth
      await _bluetoothService.disconnect();
      
      _setConnectionStatus(ConnectionStatus.disconnected);
      _sensorData = SensorData(); // Reset to default values
      
    } catch (e) {
      utils_logger.Logger.log('Error during disconnect: $e');
    }
  }
  
  // Control methods
  Future<void> togglePower() async {
    _isPowerOn = !_isPowerOn;
    await sendPowerCommand(_isPowerOn);
    notifyListeners();
  }
  
  Future<void> toggleMode() async {
    _isAutoMode = !_isAutoMode;
    await sendModeCommand(_isAutoMode);
    notifyListeners();
  }
  
  void toggleControl() {
    _isControlActive = !_isControlActive;
    if (_isControlActive) {
      startGyroscopeControl();
    } else {
      stopGyroscopeControl();
    }
    notifyListeners();
  }
  
  void setSensitivity(double value) {
    _sensitivity = value.clamp(0.0, 1.0);
    notifyListeners();
  }
  
  // Send joystick input with name compatibility
  Future<bool> sendJoystick(double x, double y) async {
    return await sendJoystickData(x, y);
  }
    // Get last control data (for UI display)
  Map<String, double> get lastControlData => {
    'x': 0.0, // Would store last joystick X value
    'y': 0.0, // Would store last joystick Y value
    'z': 0.0, // Would store last gyro Z value if needed
  };

  // Handle incoming sensor data from ESP32
  void _handleSensorData(Map<String, dynamic> data) {
    try {
      _sensorData = SensorData(
        distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
        temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
        humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
      );
      
      utils_logger.Logger.log('Updated sensor data: distance=${_sensorData.distance}, temp=${_sensorData.temperature}, humidity=${_sensorData.humidity}');
      notifyListeners();
      
    } catch (e) {
      utils_logger.Logger.log('Error parsing sensor data: $e');
    }
  }

  // Helper methods
  void _setConnectionStatus(ConnectionStatus status) {
    _connectionStatus = status;
    if (status != ConnectionStatus.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }

  void _setError(String error) {
    _errorMessage = error;
    _connectionStatus = ConnectionStatus.error;
    utils_logger.Logger.log('Error: $error');
    notifyListeners();
  }

  @override
  void dispose() {
    stopGyroscopeControl();
    _bluetoothService.disconnect();
    super.dispose();
  }
}
