import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart' as utils_logger;
import '../models/bluetooth_device.dart' as model;

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final utils_logger.Logger _logger = utils_logger.Logger();
  
  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectedDeviceAddress;
  List<model.BluetoothDevice> _devices = [];
  Function(String)? _dataCallback;
  BluetoothConnection? _connection;

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  List<model.BluetoothDevice> get devices => _devices;

  Future<bool> requestBluetoothEnable() async {
    try {
      utils_logger.Logger.log('Requesting Bluetooth enable...');
      
      // Check and request Bluetooth permissions
      if (!await _requestBluetoothPermissions()) {
        utils_logger.Logger.error('Bluetooth permissions denied');
        return false;
      }

      // Check if Bluetooth is enabled
      bool isEnabled = (await FlutterBluetoothSerial.instance.isEnabled) ?? false;
      if (!isEnabled) {
        utils_logger.Logger.log('Bluetooth is disabled, requesting to enable...');
        // Note: flutter_bluetooth_classic_serial doesn't have direct enable method
        // User needs to enable manually through system settings
        return false;
      }
      
      utils_logger.Logger.log('Bluetooth is enabled');
      return true;
    } catch (e) {
      utils_logger.Logger.error('Error requesting Bluetooth enable: $e');
      return false;
    }
  }

  Future<bool> _requestBluetoothPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetooth,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
        Permission.location,
      ].request();

      return statuses.values.every((status) => 
          status == PermissionStatus.granted || 
          status == PermissionStatus.permanentlyDenied);
    } catch (e) {
      utils_logger.Logger.error('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<model.BluetoothDevice>> scanForDevices() async {
    if (_isScanning) return _devices;
    
    try {
      _isScanning = true;
      notifyListeners();
      
      utils_logger.Logger.log('Starting Bluetooth device scan...');
      
      // Get paired devices first
      var paired = await FlutterBluetoothSerial.instance.getBondedDevices();
      _devices = paired
          .map((d) => model.BluetoothDevice.fromFlutterBluetoothSerial(d))
          .toList();
      
      utils_logger.Logger.log('Found ${_devices.length} paired devices');
      
      // Note: flutter_bluetooth_classic_serial primarily works with paired devices
      // Discovery of new devices might require different approach
      
      notifyListeners();
      return _devices;
    } catch (e) {
      utils_logger.Logger.error('Error scanning for devices: $e');
      return [];
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<bool> connectToDevice(String address) async {
    try {
      if (_isConnected) {
        await disconnect();
      }

      utils_logger.Logger.log('Attempting to connect to device: $address');
      
      // Verify the device is in our list
      model.BluetoothDevice foundDevice = _devices.firstWhere(
        (d) => d.address == address,
        orElse: () => throw Exception('Device not found'),
      );

      _connection = await BluetoothConnection.toAddress(address);
      
      if (_connection != null) {
        _isConnected = true;
        _connectedDeviceAddress = address;
        
        // Listen for incoming data
        _connection!.input!.listen(
          (data) {
            String message = String.fromCharCodes(data);
            utils_logger.Logger.log('Received data: $message');
            if (_dataCallback != null) {
              _dataCallback!(message);
            }
          },
          onError: (error) {
            utils_logger.Logger.error('Connection error: $error');
            _handleDisconnection();
          },
          onDone: () {
            utils_logger.Logger.log('Connection closed');
            _handleDisconnection();
          },
        );
        
        utils_logger.Logger.log('Successfully connected to $address');
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      utils_logger.Logger.error('Error connecting to device: $e');
      return false;
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _connectedDeviceAddress = null;
    _connection = null;
    notifyListeners();
  }

  Future<bool> sendCommand(String command) async {
    if (!_isConnected || _connection == null) {
      utils_logger.Logger.error('Not connected to any device');
      return false;
    }

    try {
      utils_logger.Logger.log('Sending command: $command');
      _connection!.output.add(Uint8List.fromList(command.codeUnits));
      await _connection!.output.allSent;
      utils_logger.Logger.log('Command sent successfully');
      return true;
    } catch (e) {
      utils_logger.Logger.error('Error sending command: $e');
      return false;
    }
  }

  Future<bool> sendJoystickData(double x, double y, [double z = 0]) async {
    String command = 'JOYSTICK:$x,$y,$z';
    return await sendCommand(command);
  }

  void setDataCallback(Function(String) callback) {
    _dataCallback = callback;
  }

  Future<void> disconnect() async {
    try {
      if (_connection != null) {
        await _connection!.close();
        _connection = null;
      }
      _isConnected = false;
      _connectedDeviceAddress = null;
      utils_logger.Logger.log('Disconnected from Bluetooth device');
      notifyListeners();
    } catch (e) {
      utils_logger.Logger.error('Error disconnecting: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
