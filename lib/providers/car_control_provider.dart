import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart';
import '../services/connection_service.dart';
import '../services/gyroscope_service.dart';
import '../models/bluetooth_device.dart';
import '../models/sensor_data.dart';
import '../utils/logger.dart';

enum ConnectionStatus { disconnected, connecting, connected, error }

class CarControlProvider with ChangeNotifier {
  // Connection status
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  String? _errorMessage;
  String? _cameraUrl;
    // Sensor data from ESP32
  SensorData _sensorData = SensorData();
  
  // Gyroscope service
  final GyroscopeService _gyroscopeService = GyroscopeService();

  // Getters
  ConnectionStatus get connectionStatus => _connectionStatus;  String get errorMessage => _errorMessage ?? '';
  String get cameraUrl => _cameraUrl ?? '';
  SensorData get sensorData => _sensorData;
  bool get isConnected => BluetoothService.isConnected;

  // Set camera URL (no connection needed, just for streaming)
  set cameraUrl(String? url) {
    _cameraUrl = url;
    notifyListeners();
  }
  // Scan for Bluetooth devices
  Future<List<BluetoothDevice>> scanBluetoothDevices() async {
    Logger.log('Starting Bluetooth device scan...');
    _setConnectionStatus(ConnectionStatus.connecting);
    
    try {
      // Check if Bluetooth is enabled
      bool isEnabled = await BluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        Logger.log('Bluetooth not enabled, requesting enable...');
        bool enabled = await BluetoothService.requestBluetoothEnable();
        if (!enabled) {
          throw Exception('Bluetooth must be enabled to scan for devices');
        }
      }

      List<BluetoothDevice> devices = await BluetoothService.scanForDevices();
      Logger.log('Found ${devices.length} Bluetooth devices');
      
      _setConnectionStatus(ConnectionStatus.disconnected);
      return devices;
      
    } catch (e) {
      _setError('Bluetooth scan failed: $e');
      return [];
    }
  }

  // Connect to Bluetooth device
  Future<bool> connectBluetooth(String address) async {
    Logger.log('Connecting to Bluetooth device: $address');
    _setConnectionStatus(ConnectionStatus.connecting);
    
    try {
      // Set up sensor data callback before connecting
      BluetoothService.setDataCallback((data) {
        _handleSensorData(data);
      });

      bool connected = await BluetoothService.connectToDevice(address);
      
      if (connected) {
        _setConnectionStatus(ConnectionStatus.connected);
        Logger.log('Successfully connected to Bluetooth device');
        
        // Send initial power on command
        await BluetoothService.sendCommand('power', true);
        
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
    Logger.log('Connecting to camera at $ipAddress:$port');
    _setConnectionStatus(ConnectionStatus.connecting);
    
    try {
      bool connected = await ConnectionService.testCameraConnection(ipAddress, port);
      
      if (connected) {
        _cameraUrl = ConnectionService.getMjpegStreamUrl();
        Logger.log('Successfully connected to camera: $_cameraUrl');
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
    _cameraUrl = '';
    Logger.log('Disconnected from camera');
    notifyListeners();
  }

  // Send joystick data
  Future<bool> sendJoystickData(double x, double y) async {
    if (!isConnected) {
      Logger.log('Cannot send joystick data: not connected');
      return false;
    }

    return await BluetoothService.sendJoystickData(x, y);
  }

  // Send power command
  Future<bool> sendPowerCommand(bool enabled) async {
    if (!isConnected) {
      Logger.log('Cannot send power command: not connected');
      return false;
    }

    return await BluetoothService.sendCommand('power', enabled);
  }

  // Send mode command
  Future<bool> sendModeCommand(bool autoMode) async {
    if (!isConnected) {
      Logger.log('Cannot send mode command: not connected');
      return false;
    }

    return await BluetoothService.sendCommand('mode', autoMode);
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
    Logger.log('Disconnecting from all services...');
    
    try {
      // Stop gyroscope
      stopGyroscopeControl();
      
      // Send power off command before disconnecting
      if (isConnected) {
        await BluetoothService.sendCommand('power', false);
        await Future.delayed(const Duration(milliseconds: 100));
      }
        // Disconnect Bluetooth
      await BluetoothService.disconnect();
      
      _setConnectionStatus(ConnectionStatus.disconnected);
      _sensorData = SensorData(); // Reset to default values
      
    } catch (e) {
      Logger.log('Error during disconnect: $e');
    }
  }
  // Handle incoming sensor data from ESP32
  void _handleSensorData(Map<String, dynamic> data) {
    try {
      _sensorData = SensorData(
        distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
        temperature: (data['temperature'] as num?)?.toDouble() ?? 0.0,
        humidity: (data['humidity'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.now(),
      );
      
      Logger.log('Updated sensor data: distance=${_sensorData.distance}, temp=${_sensorData.temperature}, humidity=${_sensorData.humidity}');
      notifyListeners();
      
    } catch (e) {
      Logger.log('Error parsing sensor data: $e');
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
    Logger.log('Error: $error');
    notifyListeners();
  }

  @override
  void dispose() {
    stopGyroscopeControl();
    BluetoothService.disconnect();
    super.dispose();
  }
}
