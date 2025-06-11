import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  String get targetAddress => _targetAddress;  // Connect via WiFi
  Future<bool> connectWifi(String ipAddress, int port) async {
    _connectionType = ConnectionType.wifi;
    _connectionStatus = ConnectionStatus.connecting;
    _targetAddress = ipAddress;
    
    try {
      Logger.log('Connecting to ESP32-CAM at $ipAddress:$port');
      
      // First try to validate that this is an ESP32 camera
      final statusUri = Uri.parse('http://$ipAddress:$port/status');
      final streamUri = Uri.parse('http://$ipAddress:$port/stream');
      
      // Create a timeout for the HTTP requests
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      
      // First check the status endpoint
      try {
        final statusRequest = await client.getUrl(statusUri);
        final statusResponse = await statusRequest.close().timeout(const Duration(seconds: 5));
        
        if (statusResponse.statusCode == 200) {
          // Read the response to verify it's an ESP32-CAM
          final content = await statusResponse.transform(utf8.decoder).join();
          if (content.contains('ESP32') || content.contains('Camera')) {
            Logger.log('Successfully validated ESP32-CAM status');
          } else {
            Logger.log('Response does not appear to be from an ESP32-CAM: $content');
            // Still proceed but with a warning
          }
        } else {
          Logger.log('Status check failed with code: ${statusResponse.statusCode}');
          // Try the stream endpoint directly
        }
      } catch (e) {
        Logger.log('Status endpoint check failed: $e');
        // Continue to try the stream endpoint
      }
      
      // Now check if the stream endpoint is accessible
      try {
        final streamRequest = await client.getUrl(streamUri);
        final streamResponse = await streamRequest.close().timeout(const Duration(seconds: 5));
        
        if (streamResponse.statusCode == 200) {
          // Check the content type to confirm it's a stream
          final contentType = streamResponse.headers.contentType?.toString() ?? '';
          if (contentType.contains('multipart') || 
              contentType.contains('video') ||
              contentType.contains('stream')) {
            Logger.log('Successfully connected to ESP32-CAM stream');
            _connectionStatus = ConnectionStatus.connected;
            return true;
          } else {
            throw Exception('Invalid stream content type: $contentType');
          }
        } else {
          throw Exception('Could not access camera stream. Status: ${streamResponse.statusCode}');
        }
      } catch (e) {
        Logger.log('Stream endpoint check failed: $e');
        throw Exception('Could not connect to camera stream: ${e.toString()}');
      }
    } catch (e) {
      _errorMessage = e.toString();
      _connectionStatus = ConnectionStatus.error;
      Logger.log('WiFi connection error: $_errorMessage');
      return false;
    }
  }  // Connect via Bluetooth
  Future<bool> connectBluetooth(String address) async {
    _connectionType = ConnectionType.bluetooth;
    _connectionStatus = ConnectionStatus.connecting;
    _targetAddress = address;
    
    try {      // Find the device with the matching address
      List<fbp.BluetoothDevice> devices = await fbp.FlutterBluePlus.systemDevices;
      
      // If device not found, try to discover it
      _bluetoothDevice = devices.firstWhere(
        (device) => device.remoteId.str == address,
        orElse: () {
          Logger.log('Device not found in known devices, attempting to create it');
          return fbp.BluetoothDevice.fromId(address);
        },
      );
        Logger.log('Connecting to device: ${_bluetoothDevice?.remoteId.str} (${_bluetoothDevice?.platformName})');
      
      // Ensure device is not already connected
      var connectedDevices = await fbp.FlutterBluePlus.connectedDevices;
      if (connectedDevices.any((device) => device.remoteId.str == address)) {
        Logger.log('Device already connected, disconnecting first');
        await _bluetoothDevice!.disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Connect to the device with timeout
      Logger.log('Attempting to connect to the Bluetooth device...');
      await _bluetoothDevice!.connect(timeout: const Duration(seconds: 15));
      
      // Wait for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Discover services
      Logger.log('Discovering services...');
      List<fbp.BluetoothService> services = await _bluetoothDevice!.discoverServices();
        // ESP32 standard UART service and characteristic UUIDs
      const String uartServiceUuid = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
      const String uartRxCharUuid = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E'; // RX from ESP32 perspective (write)
      const String uartTxCharUuid = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E'; // TX from ESP32 perspective (read)
      
      // Print all services and their characteristics for debugging
      for (var service in services) {
        Logger.log('Service: ${service.uuid.toString().toUpperCase()}');
        for (var char in service.characteristics) {
          Logger.log('  Char: ${char.uuid.toString().toUpperCase()} - '
              'Read: ${char.properties.read}, '
              'Write: ${char.properties.write}, '
              'WriteWithoutResponse: ${char.properties.writeWithoutResponse}, '
              'Notify: ${char.properties.notify}');
        }
      }
      
      // Try to find the UART service first
      fbp.BluetoothService? uartService;
      try {        uartService = services.firstWhere(
          (service) => service.uuid.toString().toUpperCase() == uartServiceUuid,
        );
        Logger.log('Found UART service: ${uartService.uuid}');
      } catch (e) {
        // If standard UART service not found, try to find any service with read/write characteristics
        Logger.log('Standard UART service not found, looking for alternative service');
        for (var service in services) {
          if (service.characteristics.any((c) => c.properties.write || c.properties.writeWithoutResponse) &&
              service.characteristics.any((c) => c.properties.read || c.properties.notify)) {
            uartService = service;
            Logger.log('Found alternative service: ${service.uuid}');
            break;
          }
        }
      }
      
      // If no suitable service found, use the first service as a fallback
      if (uartService == null) {
        if (services.isNotEmpty) {
          uartService = services.first;
          Logger.log('No suitable service found, using first service: ${uartService.uuid}');
        } else {
          throw Exception('No services found on the device');
        }
      }
      
      // Find characteristics for reading and writing
      var characteristics = uartService.characteristics;
      
      // Try to find standard characteristics first
      try {        _writeCharacteristic = characteristics.firstWhere(
          (char) => char.uuid.toString().toUpperCase() == uartRxCharUuid && 
                   (char.properties.write || char.properties.writeWithoutResponse),
        );
        Logger.log('Found standard write characteristic: ${_writeCharacteristic?.uuid}');
      } catch (e) {
        // If standard characteristic not found, find any writable characteristic
        _writeCharacteristic = characteristics.firstWhere(
          (char) => char.properties.write || char.properties.writeWithoutResponse,
          orElse: () => throw Exception('No writable characteristic found'),
        );
        Logger.log('Using alternative write characteristic: ${_writeCharacteristic?.uuid}');
      }
      
      try {        _readCharacteristic = characteristics.firstWhere(
          (char) => char.uuid.toString().toUpperCase() == uartTxCharUuid && 
                   (char.properties.notify || char.properties.indicate),
        );
        Logger.log('Found standard read characteristic: ${_readCharacteristic?.uuid}');
      } catch (e) {
        // If standard characteristic not found, find any readable characteristic
        _readCharacteristic = characteristics.firstWhere(
          (char) => char.properties.notify || char.properties.indicate || char.properties.read,
          orElse: () => throw Exception('No readable characteristic found'),
        );
        Logger.log('Using alternative read characteristic: ${_readCharacteristic?.uuid}');
      }
      
      // Enable notifications for the read characteristic
      if (_readCharacteristic!.properties.notify) {
        Logger.log('Enabling notifications for read characteristic');
        await _readCharacteristic!.setNotifyValue(true);
      } else if (_readCharacteristic!.properties.indicate) {
        Logger.log('Enabling indications for read characteristic');
        await _readCharacteristic!.setNotifyValue(true);
      }
      
      // Successfully connected
      _connectionStatus = ConnectionStatus.connected;
      Logger.log('Successfully connected to Bluetooth device and configured characteristics');
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _connectionStatus = ConnectionStatus.error;
      Logger.log('Bluetooth connection error: $_errorMessage');
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
    if (_connectionStatus != ConnectionStatus.connected) {
      Logger.log('Not connected, cannot send joystick data');
      return false;
    }
    
    try {
      final jsonData = jsonEncode(data);
      Logger.log('Sending joystick data: $jsonData');
      
      if (_connectionType == ConnectionType.bluetooth && _writeCharacteristic != null) {
        // Add a newline to trigger line-based parsing on the ESP32
        await _writeCharacteristic!.write(utf8.encode('$jsonData\n'));
        return true;
      } else if (_connectionType == ConnectionType.wifi) {
        // If we're only connected via WiFi to the camera, we can't control the car
        // This would need a separate HTTP endpoint on the ESP32-CAM for control
        Logger.log('Cannot send joystick data over WiFi connection');
        return false;
      } else {
        Logger.log('No valid connection for sending joystick data');
        return false;
      }
    } catch (e) {
      _errorMessage = e.toString();
      Logger.log('Error sending joystick data: $_errorMessage');
      return false;
    }
  }  // Listen for sensor data via Bluetooth
  void listenForSensorData(void Function(Map<String, dynamic>) onData) {
    if (_readCharacteristic != null) {
      Logger.log('Setting up sensor data listener');
      
      _dataSubscription?.cancel();
      _dataSubscription = _readCharacteristic!.lastValueStream.listen((value) {
        if (value.isEmpty) return;
        
        try {
          // Convert bytes to string
          final message = utf8.decode(value);
          Logger.log('Raw data received: $message');
          
          // Some ESP32 implementations might send multiple JSON objects or have extra characters
          // Try to extract valid JSON
          String cleanedMessage = message.trim();
          
          // If the message contains multiple lines, process each one
          for (var line in cleanedMessage.split('\n')) {
            line = line.trim();
            if (line.isEmpty) continue;
            
            // Try to find a valid JSON object in the line
            try {
              // If line starts with '{' and ends with '}', it's likely a valid JSON
              if (line.startsWith('{') && line.endsWith('}')) {
                final json = jsonDecode(line);
                
                // Validate that this is sensor data
                if (json is Map<String, dynamic> && 
                   (json.containsKey('distance') || 
                    json.containsKey('temp') || 
                    json.containsKey('temperature') ||
                    json.containsKey('humidity'))) {
                  
                  Logger.log('Valid sensor data received: $json');
                  onData(json);
                  break; // Process only one valid sensor data object
                }
              }
            } catch (e) {
              Logger.log('Error parsing JSON from line: $e');
            }
          }
        } catch (e) {
          Logger.log('Error processing received data: $e');
        }
      });
    } else {
      Logger.log('Read characteristic not available for sensor data');
    }
  }// Scan for Bluetooth devices
  Future<List<bt_device.BluetoothDevice>> scanBluetoothDevices() async {
    try {
      Logger.log('Starting Bluetooth scan');
      
      // Request bluetooth permissions first if needed
      // These permissions are handled by the flutter_blue_plus plugin
      
      // Stop any previous scans
      await fbp.FlutterBluePlus.stopScan();
      
      // Actually scan for real Bluetooth devices with a longer timeout
      await fbp.FlutterBluePlus.startScan(timeout: const Duration(seconds: 8));
      
      // Wait for scan results
      List<fbp.ScanResult> scanResults = await fbp.FlutterBluePlus.scanResults.first;
      
      Logger.log('Raw scan found ${scanResults.length} devices');
      
      // Filter for ESP32 devices first with better matching      var filteredResults = scanResults.where((result) {
        final deviceName = result.device.platformName.toLowerCase();
        final deviceId = result.device.remoteId.str.toLowerCase();
        return deviceName.contains('esp') || 
               deviceName.contains('gyro') || 
               deviceName.contains('car') ||
               deviceId.startsWith('24:6f:28') || // Common ESP32 MAC prefix
               deviceId.startsWith('24:0a:c4') ||
               deviceId.startsWith('30:ae:a4') ||
               deviceId.startsWith('8c:aa:b5');
      }).toList();
      
      // Sort by RSSI (signal strength) to prioritize nearby devices
      filteredResults.sort((a, b) => b.rssi.compareTo(a.rssi));
      
      // If no ESP devices found, show all discoverable devices
      if (filteredResults.isEmpty) {
        Logger.log('No ESP32 devices found, showing all devices');
        filteredResults = scanResults
          ..sort((a, b) => b.rssi.compareTo(a.rssi));
      } else {
        Logger.log('Found ${filteredResults.length} potential ESP32 devices');
      }
        // Convert to our BluetoothDevice model with additional information
      return filteredResults.map((result) {
        final deviceName = result.device.platformName.isNotEmpty 
            ? result.device.platformName 
            : 'Unknown Device';
        final signalStrength = result.rssi > -70 ? 'Strong' : 
                             result.rssi > -90 ? 'Medium' : 'Weak';
            
        return bt_device.BluetoothDevice(
          name: deviceName,
          address: result.device.remoteId.str,
          rssi: result.rssi,
          signalStrength: signalStrength,
        );
      }).toList();
    } catch (e) {
      _errorMessage = "Bluetooth scan failed: ${e.toString()}";
      Logger.log('Bluetooth scan error: $_errorMessage');
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
