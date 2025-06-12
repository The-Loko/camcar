import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart' as utils_logger;

class BluetoothService extends ChangeNotifier {
  static final BluetoothService _instance = BluetoothService._internal();
  factory BluetoothService() => _instance;
  BluetoothService._internal();

  final utils_logger.Logger _logger = utils_logger.Logger();
  
  bool _isScanning = false;
  bool _isConnected = false;
  String? _connectedDeviceAddress;
  List<BluetoothDevice> _devices = [];
  Function(String)? _dataCallback;
  BluetoothConnection? _connection;

  bool get isScanning => _isScanning;
  bool get isConnected => _isConnected;
  String? get connectedDeviceAddress => _connectedDeviceAddress;
  List<BluetoothDevice> get devices => _devices;

  Future<bool> requestBluetoothEnable() async {
    try {
      _logger.log('Requesting Bluetooth enable...');
      
      // Check and request Bluetooth permissions
      if (!await _requestBluetoothPermissions()) {
        _logger.error('Bluetooth permissions denied');
        return false;
      }

      // Check if Bluetooth is enabled
      bool isEnabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (!isEnabled) {
        _logger.log('Bluetooth is disabled, requesting to enable...');
        // Note: flutter_bluetooth_classic_serial doesn't have direct enable method
        // User needs to enable manually through system settings
        return false;
      }
      
      _logger.log('Bluetooth is enabled');
      return true;
    } catch (e) {
      _logger.error('Error requesting Bluetooth enable: $e');
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
      _logger.error('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<BluetoothDevice>> scanForDevices() async {
    if (_isScanning) return _devices;
    
    try {
      _isScanning = true;
      notifyListeners();
      
      _logger.log('Starting Bluetooth device scan...');
      
      // Get paired devices first
      List<BluetoothDevice> pairedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      _devices = pairedDevices;
      
      _logger.log('Found ${_devices.length} paired devices');
      
      // Note: flutter_bluetooth_classic_serial primarily works with paired devices
      // Discovery of new devices might require different approach
      
      notifyListeners();
      return _devices;
    } catch (e) {
      _logger.error('Error scanning for devices: $e');
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

      _logger.log('Attempting to connect to device: $address');
      
      BluetoothDevice? device = _devices.firstWhere(
        (d) => d.address == address,
        orElse: () => throw Exception('Device not found'),
      );

      _connection = await BluetoothConnection.toAddress(address);
      
      if (_connection != null) {
        _isConnected = true;
        _connectedDeviceAddress = address;
        
        // Listen for incoming data
        _connection!.input!.listen(
          (Uint8List data) {
            String message = String.fromCharCodes(data);
            _logger.log('Received data: $message');
            if (_dataCallback != null) {
              _dataCallback!(message);
            }
          },
          onError: (error) {
            _logger.error('Connection error: $error');
            _handleDisconnection();
          },
          onDone: () {
            _logger.log('Connection closed');
            _handleDisconnection();
          },
        );
        
        _logger.log('Successfully connected to $address');
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      _logger.error('Error connecting to device: $e');
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
      _logger.error('Not connected to any device');
      return false;
    }

    try {
      _logger.log('Sending command: $command');
      _connection!.output.add(Uint8List.fromList(command.codeUnits));
      await _connection!.output.allSent;
      _logger.log('Command sent successfully');
      return true;
    } catch (e) {
      _logger.error('Error sending command: $e');
      return false;
    }
  }

  Future<bool> sendJoystickData(double x, double y, double z) async {
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
      _logger.log('Disconnected from Bluetooth device');
      notifyListeners();
    } catch (e) {
      _logger.error('Error disconnecting: $e');
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
