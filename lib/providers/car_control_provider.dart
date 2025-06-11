import 'package:flutter/foundation.dart';
import '../services/gyroscope_service.dart';
import '../services/connection_service.dart';
import '../models/control_data.dart';
import '../models/bluetooth_device.dart';
import '../models/wifi_network.dart';

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
    notifyListeners();
    return result;
  }

  Future<bool> connectBluetooth(String address) async {
    final result = await _connectionService.connectBluetooth(address);
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

  @override
  void dispose() {
    _gyroscopeService.dispose();
    _connectionService.disconnect();
    super.dispose();
  }
}
