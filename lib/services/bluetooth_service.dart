import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../utils/logger.dart';
import '../models/bluetooth_device.dart' as bt_model;

class BluetoothService {
  static BluetoothConnection? _connection;
  static bool _isConnected = false;
  static String? _connectedDeviceAddress;
  static Function(Map<String, dynamic>)? _dataCallback;

  // Get connection status
  static bool get isConnected => _isConnected;
  static String? get connectedDeviceAddress => _connectedDeviceAddress;

  // Scan for Bluetooth devices (specifically looking for "GyroCar")
  static Future<List<bt_model.BluetoothDevice>> scanForDevices() async {
    Logger.log('Starting Bluetooth Classic device scan...');
    List<bt_model.BluetoothDevice> devices = [];

    try {
      // Check if Bluetooth is enabled
      bool isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
      if (!isEnabled) {
        throw Exception('Bluetooth is not enabled. Please turn on Bluetooth and try again.');
      }

      // Get bonded (paired) devices first
      Logger.log('Checking bonded devices...');
      List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      
      for (BluetoothDevice device in bondedDevices) {
        if (device.name != null && device.name!.isNotEmpty) {
          Logger.log('Found bonded device: ${device.name} (${device.address})');
          devices.add(bt_model.BluetoothDevice(
            name: device.name!,
            address: device.address,
            rssi: -50, // Default for bonded devices
            signalStrength: 'Paired',
          ));
        }
      }

      // Discover new devices
      Logger.log('Starting device discovery...');
      bool isDiscovering = await FlutterBluetoothSerial.instance.isDiscovering ?? false;
      if (isDiscovering) {
        await FlutterBluetoothSerial.instance.cancelDiscovery();
      }

      // Start discovery and collect results
      await FlutterBluetoothSerial.instance.startDiscovery().forEach((result) {
        if (result.device.name != null && result.device.name!.isNotEmpty) {
          Logger.log('Discovered device: ${result.device.name} (${result.device.address}) RSSI: ${result.rssi}');
          
          // Don't add duplicates
          bool alreadyExists = devices.any((d) => d.address == result.device.address);
          if (!alreadyExists) {
            String signalStrength = result.rssi > -50 ? 'Excellent' :
                                   result.rssi > -60 ? 'Very Good' :
                                   result.rssi > -70 ? 'Good' : 
                                   result.rssi > -80 ? 'Fair' : 'Poor';
            
            devices.add(bt_model.BluetoothDevice(
              name: result.device.name!,
              address: result.device.address,
              rssi: result.rssi,
              signalStrength: signalStrength,
            ));
          }
        }
      });

      Logger.log('Bluetooth scan completed. Found ${devices.length} devices');

      // Filter and prioritize ESP32/GyroCar devices
      devices.sort((a, b) {
        // Prioritize "GyroCar" devices
        bool aIsGyroCar = a.name.toLowerCase().contains('gyrocar');
        bool bIsGyroCar = b.name.toLowerCase().contains('gyrocar');
        
        if (aIsGyroCar && !bIsGyroCar) return -1;
        if (!aIsGyroCar && bIsGyroCar) return 1;
        
        // Then prioritize ESP32-like devices
        bool aIsESP32 = a.name.toLowerCase().contains('esp') || 
                       a.address.startsWith('24:6f:28') ||
                       a.address.startsWith('24:0a:c4') ||
                       a.address.startsWith('30:ae:a4');
        bool bIsESP32 = b.name.toLowerCase().contains('esp') || 
                       b.address.startsWith('24:6f:28') ||
                       b.address.startsWith('24:0a:c4') ||
                       b.address.startsWith('30:ae:a4');
        
        if (aIsESP32 && !bIsESP32) return -1;
        if (!aIsESP32 && bIsESP32) return 1;
        
        // Finally sort by signal strength
        return (b.rssi ?? -100).compareTo(a.rssi ?? -100);
      });

      return devices;

    } catch (e) {
      Logger.log('Error scanning for devices: $e');
      throw Exception('Failed to scan for Bluetooth devices: $e');
    }
  }

  // Connect to a Bluetooth device
  static Future<bool> connectToDevice(String address) async {
    try {
      Logger.log('Attempting to connect to device: $address');

      // Disconnect if already connected
      if (_isConnected) {
        await disconnect();
      }

      // Connect to the device
      _connection = await BluetoothConnection.toAddress(address);
      _isConnected = true;
      _connectedDeviceAddress = address;

      Logger.log('Successfully connected to $address');

      // Listen for incoming data
      _connection!.input!.listen((Uint8List data) {
        String received = utf8.decode(data).trim();
        Logger.log('Received data: $received');
        
        // Try to parse as JSON
        try {
          Map<String, dynamic> jsonData = jsonDecode(received);
          _dataCallback?.call(jsonData);
        } catch (e) {
          Logger.log('Failed to parse received data as JSON: $e');
        }
      }).onDone(() {
        Logger.log('Bluetooth connection closed');
        _isConnected = false;
        _connectedDeviceAddress = null;
      });

      return true;

    } catch (e) {
      Logger.log('Failed to connect to device: $e');
      _isConnected = false;
      _connectedDeviceAddress = null;
      return false;
    }
  }

  // Send joystick data to ESP32
  static Future<bool> sendJoystickData(double x, double y) async {
    if (!_isConnected || _connection == null) {
      Logger.log('Cannot send data: not connected');
      return false;
    }

    try {
      // Create JSON data matching ESP32 expected format
      Map<String, dynamic> data = {
        'x': x,
        'y': y,
      };
      
      String jsonString = '${jsonEncode(data)}\n'; // ESP32 expects newline
      Logger.log('Sending joystick data: $jsonString');
      
      _connection!.output.add(utf8.encode(jsonString));
      await _connection!.output.allSent;
      
      return true;
    } catch (e) {
      Logger.log('Error sending joystick data: $e');
      return false;
    }
  }

  // Send command data to ESP32
  static Future<bool> sendCommand(String command, dynamic value) async {
    if (!_isConnected || _connection == null) {
      Logger.log('Cannot send command: not connected');
      return false;
    }

    try {
      // Create command JSON matching ESP32 expected format
      Map<String, dynamic> data = {
        'cmd': command,
        'value': value,
      };
      
      String jsonString = '${jsonEncode(data)}\n'; // ESP32 expects newline
      Logger.log('Sending command: $jsonString');
      
      _connection!.output.add(utf8.encode(jsonString));
      await _connection!.output.allSent;
      
      return true;
    } catch (e) {
      Logger.log('Error sending command: $e');
      return false;
    }
  }

  // Set callback for receiving sensor data
  static void setDataCallback(Function(Map<String, dynamic>) callback) {
    _dataCallback = callback;
  }

  // Disconnect from device
  static Future<void> disconnect() async {
    try {
      if (_connection != null) {
        await _connection!.close();
        _connection = null;
      }
      _isConnected = false;
      _connectedDeviceAddress = null;
      _dataCallback = null;
      Logger.log('Disconnected from Bluetooth device');
    } catch (e) {
      Logger.log('Error disconnecting: $e');
    }
  }

  // Check if Bluetooth is enabled
  static Future<bool> isBluetoothEnabled() async {
    try {
      bool? isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      return isEnabled ?? false;
    } catch (e) {
      Logger.log('Error checking Bluetooth status: $e');
      return false;
    }
  }

  // Request to enable Bluetooth
  static Future<bool> requestBluetoothEnable() async {
    try {
      bool? result = await FlutterBluetoothSerial.instance.requestEnable();
      return result ?? false;
    } catch (e) {
      Logger.log('Error requesting Bluetooth enable: $e');
      return false;
    }
  }
}
