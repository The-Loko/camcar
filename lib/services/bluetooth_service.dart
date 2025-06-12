import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';
import '../utils/logger.dart';
import '../models/bluetooth_device.dart' as bt_model;

class BluetoothService {
  static final FlutterBluetoothClassic _bluetooth = FlutterBluetoothClassic();
  static bool _isConnected = false;
  static String? _connectedDeviceAddress;
  static Function(Map<String, dynamic>)? _dataCallback;

  // Get connection status
  static bool get isConnected => _isConnected;
  static String? get connectedDeviceAddress => _connectedDeviceAddress;

  // Initialize Bluetooth and check permissions
  static Future<bool> initialize() async {
    try {
      Logger.log('Initializing Bluetooth Classic...');
      
      // Check if Bluetooth is supported
      bool isSupported = await _bluetooth.isBluetoothSupported();
      if (!isSupported) {
        throw Exception('Bluetooth is not supported on this device');
      }

      // Check if Bluetooth is enabled
      bool isEnabled = await _bluetooth.isBluetoothEnabled();
      if (!isEnabled) {
        throw Exception('Bluetooth is not enabled. Please turn on Bluetooth and try again.');
      }

      Logger.log('Bluetooth Classic initialized successfully');
      return true;
    } catch (e) {
      Logger.error('Failed to initialize Bluetooth: $e');
      return false;
    }
  }

  // Scan for Bluetooth devices (specifically looking for "GyroCar")
  static Future<List<bt_model.BluetoothDevice>> scanForDevices() async {
    Logger.log('Starting Bluetooth Classic device scan...');
    List<bt_model.BluetoothDevice> devices = [];

    try {
      // Initialize Bluetooth first
      bool initialized = await initialize();
      if (!initialized) {
        throw Exception('Failed to initialize Bluetooth');
      }

      // Get paired devices first
      Logger.log('Checking paired devices...');
      List<BluetoothDevice> pairedDevices = await _bluetooth.getPairedDevices();
      
      for (BluetoothDevice device in pairedDevices) {
        if (device.name.isNotEmpty) {
          Logger.log('Found paired device: ${device.name} (${device.address})');
          devices.add(bt_model.BluetoothDevice(
            name: device.name,
            address: device.address,
            rssi: -50, // Default for paired devices
            signalStrength: 'Paired',
          ));
        }
      }

      // Start device discovery for new devices
      Logger.log('Starting device discovery...');
      List<BluetoothDevice> discoveredDevices = await _bluetooth.discoverDevices();
      
      for (BluetoothDevice device in discoveredDevices) {
        // Avoid duplicates (already paired devices)
        bool alreadyExists = devices.any((existingDevice) => 
            existingDevice.address == device.address);
        
        if (!alreadyExists && device.name.isNotEmpty) {
          Logger.log('Discovered new device: ${device.name} (${device.address})');
          devices.add(bt_model.BluetoothDevice(
            name: device.name,
            address: device.address,
            rssi: -60, // Default for discovered devices
            signalStrength: 'Available',
          ));
        }
      }

      Logger.log('Device scan completed. Found ${devices.length} devices');
      return devices;
    } catch (e) {
      Logger.error('Device scan failed: $e');
      return devices; // Return whatever devices we found
    }
  }

  // Connect to a Bluetooth device
  static Future<bool> connect(String deviceAddress) async {
    try {
      Logger.log('Attempting to connect to device: $deviceAddress');

      // Disconnect if already connected
      if (_isConnected) {
        await disconnect();
      }

      // Initialize Bluetooth first
      bool initialized = await initialize();
      if (!initialized) {
        throw Exception('Failed to initialize Bluetooth');
      }

      // Connect to the device
      bool connected = await _bluetooth.connect(deviceAddress);
      
      if (connected) {
        _isConnected = true;
        _connectedDeviceAddress = deviceAddress;
        
        // Set up data listener
        _bluetooth.onDataReceived.listen((data) {
          try {
            String receivedString = data.asString();
            Logger.log('Received data: $receivedString');
            
            // Try to parse as JSON for sensor data
            if (receivedString.startsWith('{') && receivedString.endsWith('}')) {
              Map<String, dynamic> jsonData = json.decode(receivedString);
              _dataCallback?.call(jsonData);
            } else {
              // Handle plain text messages
              _dataCallback?.call({'message': receivedString});
            }
          } catch (e) {
            Logger.error('Failed to process received data: $e');
          }
        });

        Logger.log('Successfully connected to $deviceAddress');
        return true;
      } else {
        throw Exception('Failed to establish connection');
      }
    } catch (e) {
      Logger.error('Connection failed: $e');
      _isConnected = false;
      _connectedDeviceAddress = null;
      return false;
    }
  }

  // Disconnect from the current device
  static Future<void> disconnect() async {
    try {
      if (_isConnected) {
        Logger.log('Disconnecting from device: $_connectedDeviceAddress');
        await _bluetooth.disconnect();
        _isConnected = false;
        _connectedDeviceAddress = null;
        Logger.log('Disconnected successfully');
      }
    } catch (e) {
      Logger.error('Disconnect failed: $e');
      // Reset state anyway
      _isConnected = false;
      _connectedDeviceAddress = null;
    }
  }

  // Send string data to the connected device
  static Future<bool> sendString(String data) async {
    try {
      if (!_isConnected) {
        throw Exception('No device connected');
      }

      Logger.log('Sending data: $data');
      await _bluetooth.sendString(data);
      Logger.log('Data sent successfully');
      return true;
    } catch (e) {
      Logger.error('Failed to send data: $e');
      return false;
    }
  }

  // Send raw bytes to the connected device
  static Future<bool> sendBytes(Uint8List data) async {
    try {
      if (!_isConnected) {
        throw Exception('No device connected');
      }

      Logger.log('Sending ${data.length} bytes');
      await _bluetooth.sendBytes(data);
      Logger.log('Bytes sent successfully');
      return true;
    } catch (e) {
      Logger.error('Failed to send bytes: $e');
      return false;
    }
  }

  // Send joystick control data
  static Future<bool> sendJoystickData(double x, double y, double z) async {
    Map<String, dynamic> controlData = {
      'type': 'joystick',
      'x': x.toStringAsFixed(2),
      'y': y.toStringAsFixed(2),
      'z': z.toStringAsFixed(2),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    String jsonString = json.encode(controlData);
    return await sendString(jsonString);
  }

  // Send gyroscope control data
  static Future<bool> sendGyroscopeData(double x, double y, double z) async {
    Map<String, dynamic> controlData = {
      'type': 'gyroscope',
      'x': x.toStringAsFixed(2),
      'y': y.toStringAsFixed(2),
      'z': z.toStringAsFixed(2),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    String jsonString = json.encode(controlData);
    return await sendString(jsonString);
  }

  // Send car control commands
  static Future<bool> sendCarCommand(String command, [Map<String, dynamic>? params]) async {
    Map<String, dynamic> commandData = {
      'type': 'command',
      'command': command,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    if (params != null) {
      commandData.addAll(params);
    }

    String jsonString = json.encode(commandData);
    return await sendString(jsonString);
  }

  // Set callback for incoming data
  static void setDataCallback(Function(Map<String, dynamic>) callback) {
    _dataCallback = callback;
  }

  // Remove data callback
  static void removeDataCallback() {
    _dataCallback = null;
  }

  // Check if Bluetooth is enabled
  static Future<bool> isBluetoothEnabled() async {
    try {
      return await _bluetooth.isBluetoothEnabled();
    } catch (e) {
      Logger.error('Failed to check Bluetooth status: $e');
      return false;
    }
  }

  // Check if Bluetooth is supported
  static Future<bool> isBluetoothSupported() async {
    try {
      return await _bluetooth.isBluetoothSupported();
    } catch (e) {
      Logger.error('Failed to check Bluetooth support: $e');
      return false;
    }
  }
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
