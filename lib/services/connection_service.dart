import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:wifi_scan/wifi_scan.dart' as wifi_scan;
import '../models/control_data.dart';
import '../models/bluetooth_device.dart' as bt_device;
import '../models/wifi_network.dart';
import '../utils/logger.dart';

enum ConnectionType { wifi, bluetooth, none }
enum ConnectionStatus { connected, disconnected, connecting, error }

class ConnectionService {
  ConnectionType _connectionType = ConnectionType.none;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  fbp.BluetoothDevice? _bluetoothDevice;
  fbp.BluetoothCharacteristic? _writeCharacteristic;
  fbp.BluetoothCharacteristic? _readCharacteristic;
  String _errorMessage = '';
  String _targetAddress = '';
  StreamSubscription<List<int>>? _dataSubscription;

  // Getters
  ConnectionType get connectionType => _connectionType;
  ConnectionStatus get connectionStatus => _connectionStatus;
  String get errorMessage => _errorMessage;
  String get targetAddress => _targetAddress;

  // Connect via WiFi
  Future<bool> connectWifi(String ipAddress, int port) async {
    _connectionType = ConnectionType.wifi;
    _connectionStatus = ConnectionStatus.connecting;
    _targetAddress = ipAddress;
    
    try {
      // In a real implementation, you would establish a TCP/IP socket connection here
      // For this example, we'll simulate a successful connection
      await Future.delayed(const Duration(seconds: 1));
      
      _connectionStatus = ConnectionStatus.connected;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _connectionStatus = ConnectionStatus.error;
      return false;
    }
  }

  // Connect via Bluetooth
  Future<bool> connectBluetooth(String address) async {
    _connectionType = ConnectionType.bluetooth;
    _connectionStatus = ConnectionStatus.connecting;
    _targetAddress = address;
    
    try {
      // For flutter_blue_plus, we need to find the device and connect
      // This is a simplified version - in a real app you'd scan and find the device
      var devices = fbp.FlutterBluePlus.connectedDevices;
      
      // For demo purposes, we'll simulate a successful connection
      _connectionStatus = ConnectionStatus.connected;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _connectionStatus = ConnectionStatus.error;
      return false;
    }
  }

  // Disconnect
  Future<void> disconnect() async {
    if (_connectionType == ConnectionType.bluetooth) {
      await _dataSubscription?.cancel();
      await _bluetoothDevice?.disconnect();
      _bluetoothDevice = null;
      _writeCharacteristic = null;
      _readCharacteristic = null;
    }
    // For WiFi, close any open socket connections
    
    _connectionStatus = ConnectionStatus.disconnected;
    _connectionType = ConnectionType.none;
  }

  // Send control data
  Future<bool> sendControlData(ControlData data) async {
    if (_connectionStatus != ConnectionStatus.connected) {
      return false;
    }

    final jsonData = jsonEncode(data.toJson());
    
    try {
      if (_connectionType == ConnectionType.bluetooth && _writeCharacteristic != null) {
        await _writeCharacteristic!.write(utf8.encode('$jsonData\n'));
      } else if (_connectionType == ConnectionType.wifi) {
        // In a real implementation, you would send data over the TCP/IP socket
        // For this example, we'll just simulate sending data
      }
      return true;
    } catch (e) {
      _errorMessage = "Data sending error: ${e.toString()}";
      _connectionStatus = ConnectionStatus.error;
      return false;
    }
  }

  // Send joystick data via Bluetooth
  Future<bool> sendJoystickData(Map<String, dynamic> data) async {
    if (_connectionStatus != ConnectionStatus.connected || _connectionType != ConnectionType.bluetooth) {
      return false;
    }
    try {
      final jsonData = jsonEncode(data);
      if (_writeCharacteristic != null) {
        await _writeCharacteristic!.write(utf8.encode('$jsonData\n'));
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    }
  }

  // Listen for sensor data via Bluetooth
  void listenForSensorData(void Function(Map<String, dynamic>) onData) {
    if (_readCharacteristic != null) {
      _dataSubscription = _readCharacteristic!.lastValueStream.listen((value) {
        final msg = utf8.decode(value);
        try {
          final json = jsonDecode(msg.trim());
          onData(json);
        } catch (_) {}
      });
    }
  }

  // Scan for Bluetooth devices
  Future<List<bt_device.BluetoothDevice>> scanBluetoothDevices() async {
    try {
      // For flutter_blue_plus, we'll return some mock devices for now
      // In a real implementation, you'd use FlutterBluePlus.startScan()
      return [
        bt_device.BluetoothDevice(name: 'GyroCar', address: '00:11:22:33:44:55'),
        bt_device.BluetoothDevice(name: 'ESP32-CAM', address: '00:11:22:33:44:56'),
      ];
    } catch (e) {
      _errorMessage = "Bluetooth scan failed: ${e.toString()}";
      return [];
    }
  }

  // Scan for WiFi networks
  Future<List<WiFiNetwork>> scanWifiNetworks() async {
    try {
      final wifiScanInstance = wifi_scan.WiFiScan.instance;
      final canStartScan = await wifiScanInstance.canStartScan();
      Logger.log('Can start scan: $canStartScan');
      
      if (canStartScan == wifi_scan.CanStartScan.yes) {
        final started = await wifiScanInstance.startScan();
        if (started) {
          Logger.log('Scan started');
          await Future.delayed(const Duration(seconds: 2));
          
          final accessPoints = await wifiScanInstance.getScannedResults();
          Logger.log('Found ${accessPoints.length} WiFi networks');
          return accessPoints.map((ap) => WiFiNetwork.fromWiFiAccessPoint(ap)).toList();
        }
        Logger.log('Scan result: $started');
      }
      return [];
    } catch (e) {
      _errorMessage = "WiFi scan failed: ${e.toString()}";
      Logger.log('WiFi scan error: $_errorMessage');
      return [];
    }
  }
}
