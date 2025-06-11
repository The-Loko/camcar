import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';  // Add this import for Uint8List
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart' as fbs;
import 'package:wifi_scan/wifi_scan.dart' as wifi_scan; // Re-add alias 'wifi_scan'
import '../models/control_data.dart';
import '../models/bluetooth_device.dart';
import '../models/wifi_network.dart';
import '../utils/logger.dart';


enum ConnectionType { wifi, bluetooth, none }
enum ConnectionStatus { connected, disconnected, connecting, error }

class ConnectionService {
  ConnectionType _connectionType = ConnectionType.none;
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  fbs.BluetoothConnection? _bluetoothConnection;
  String _errorMessage = '';
  String _targetAddress = '';

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
      _bluetoothConnection = await fbs.BluetoothConnection.toAddress(address);
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
      await _bluetoothConnection?.close();
      _bluetoothConnection = null;
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
      if (_connectionType == ConnectionType.bluetooth && _bluetoothConnection != null) {
        _bluetoothConnection!.output.add(Uint8List.fromList(utf8.encode("$jsonData\n")));
        // Add timeout to prevent hanging if connection has issues
        await _bluetoothConnection!.output.allSent.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            throw TimeoutException('Bluetooth data sending timeout');
          },
        );
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

  // Scan for Bluetooth devices
  Future<List<BluetoothDevice>> scanBluetoothDevices() async {
    try {
      final devices = await fbs.FlutterBluetoothSerial.instance.getBondedDevices()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Bluetooth scan timeout');
            },
          );
      return devices.map((device) => BluetoothDevice.fromFlutterBluetoothSerial(device)).toList();
    } catch (e) {
      _errorMessage = "Bluetooth scan failed: ${e.toString()}";
      return [];
    }
  }

  // Scan for WiFi networks
  Future<List<WiFiNetwork>> scanWifiNetworks() async {
    try {
      final wifiScanInstance = wifi_scan.WiFiScan.instance; // Use alias
      final canStartScan = await wifiScanInstance.canStartScan();
      Logger.log('Can start scan: $canStartScan');
      
      if (canStartScan == wifi_scan.CanStartScan.yes) { // Use alias
        final started = await wifiScanInstance.startScan();    // startScan() returns a bool
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
