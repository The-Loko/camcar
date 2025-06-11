import 'package:flutter/foundation.dart';
import '../services/gyroscope_service.dart';
import '../services/connection_service.dart';
import '../models/control_data.dart';
import '../models/bluetooth_device.dart';
import '../models/wifi_network.dart';
import '../models/sensor_data.dart';

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
    final result = await _connectionService.connectWifi(ipAddress, port);
    if (result) {
      cameraUrl = 'http://$ipAddress:$port/stream';
    }
    notifyListeners();
    return result;
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
  }

  void _handleSensorJson(Map<String, dynamic> json) {
    _sensorData = SensorData.fromJson(json);
    notifyListeners();
  }

  Future<bool> connectBluetooth(String address) async {
    final result = await _connectionService.connectBluetooth(address);
    if (result) {
      _connectionService.listenForSensorData(_handleSensorJson);
    }
    notifyListeners();
    return result;
  }

  Future<void> disconnect() async {
    await _connectionService.disconnect();
    notifyListeners();
  }
  Future<List<BluetoothDevice>> scanBluetoothDevices() {
    return _connectionService.scanBluetoothDevices();
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
