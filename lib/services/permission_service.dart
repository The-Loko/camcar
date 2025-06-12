import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class PermissionService {  static Future<bool> requestBluetoothPermissions() async {
    Logger.log('Requesting Bluetooth and location permissions');
    
    try {
      // List of required permissions for Bluetooth operations
      final permissions = <Permission>[
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
        Permission.locationWhenInUse,
      ];
      
      // Check current permission status first
      Map<Permission, PermissionStatus> currentStatuses = {};
      for (var permission in permissions) {
        currentStatuses[permission] = await permission.status;
      }
      
      // Log current status
      Logger.log('Current permission statuses:');
      for (var entry in currentStatuses.entries) {
        Logger.log('${entry.key.toString()}: ${entry.value.toString()}');
      }
      
      // Request permissions that are not granted
      List<Permission> toRequest = [];
      for (var permission in permissions) {
        if (currentStatuses[permission]?.isGranted != true) {
          toRequest.add(permission);
        }
      }
      
      Map<Permission, PermissionStatus> statuses = {};
      
      if (toRequest.isNotEmpty) {
        Logger.log('Requesting permissions: ${toRequest.map((p) => p.toString()).join(', ')}');
        statuses = await toRequest.request();
      } else {
        statuses = currentStatuses;
      }
      
      // Log permission statuses after request
      Logger.log('Permission statuses after request:');
      for (var entry in statuses.entries) {
        Logger.log('${entry.key.toString()}: ${entry.value.toString()}');
      }
        
      // Check if all critical permissions are granted
      bool bluetoothGranted = (statuses[Permission.bluetooth]?.isGranted ?? false) || 
                             (statuses[Permission.bluetoothScan]?.isGranted ?? false);
      bool bluetoothScanGranted = (statuses[Permission.bluetoothScan]?.isGranted ?? false) || 
                                 (statuses[Permission.bluetooth]?.isGranted ?? false);
      bool bluetoothConnectGranted = (statuses[Permission.bluetoothConnect]?.isGranted ?? false) || 
                                    (statuses[Permission.bluetooth]?.isGranted ?? false);
      bool locationGranted = (statuses[Permission.location]?.isGranted ?? false) || 
                            (statuses[Permission.locationWhenInUse]?.isGranted ?? false);
      
      // For Android 12+, we need BLUETOOTH_SCAN and BLUETOOTH_CONNECT
      // For older versions, we need BLUETOOTH and LOCATION
      bool allGranted = (bluetoothGranted && bluetoothScanGranted && bluetoothConnectGranted) || 
                       (bluetoothGranted && locationGranted);
      
      if (allGranted) {
        Logger.log('All required Bluetooth permissions granted');
        return true;
      } else {
        Logger.log('Some critical Bluetooth permissions denied');
        Logger.log('Bluetooth granted: $bluetoothGranted');
        Logger.log('Bluetooth scan granted: $bluetoothScanGranted');
        Logger.log('Bluetooth connect granted: $bluetoothConnectGranted');
        Logger.log('Location granted: $locationGranted');
        
        // Check for permanently denied permissions
        List<Permission> permanentlyDenied = [];
        for (var entry in statuses.entries) {
          if (entry.value.isPermanentlyDenied) {
            permanentlyDenied.add(entry.key);
          }
        }
        
        if (permanentlyDenied.isNotEmpty) {
          Logger.log('Some permissions permanently denied: $permanentlyDenied');
          // Guide user to settings
          return false;
        }
        
        return false;
      }
    } catch (e) {
      Logger.log('Error requesting permissions: $e');
      return false;
    }
  }
    static Future<bool> hasBluetoothPermissions() async {
    try {
      final permissions = <Permission>[
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
        Permission.locationWhenInUse,
      ];
      
      Map<Permission, PermissionStatus> statuses = {};
      for (var permission in permissions) {
        statuses[permission] = await permission.status;
      }
      
      Logger.log('Checking permission status:');
      for (var entry in statuses.entries) {
        Logger.log('${entry.key.toString()}: ${entry.value.toString()}');
      }
        
      bool bluetoothGranted = statuses[Permission.bluetooth]?.isGranted == true;
      bool bluetoothScanGranted = statuses[Permission.bluetoothScan]?.isGranted == true;
      bool bluetoothConnectGranted = statuses[Permission.bluetoothConnect]?.isGranted == true;
      bool locationGranted = (statuses[Permission.location]?.isGranted == true) || 
                            (statuses[Permission.locationWhenInUse]?.isGranted == true);
      
      // Check for different Android versions compatibility
      // Android 12+ (API 31+): needs BLUETOOTH_SCAN and BLUETOOTH_CONNECT
      // Older versions: needs BLUETOOTH and LOCATION
      bool hasRequiredPermissions = (bluetoothScanGranted && bluetoothConnectGranted) || 
                                   (bluetoothGranted && locationGranted);
      
      Logger.log('Permission summary:');
      Logger.log('  Bluetooth: $bluetoothGranted');
      Logger.log('  Bluetooth Scan: $bluetoothScanGranted');
      Logger.log('  Bluetooth Connect: $bluetoothConnectGranted');
      Logger.log('  Location: $locationGranted');
      Logger.log('  Has required permissions: $hasRequiredPermissions');
      
      return hasRequiredPermissions;
    } catch (e) {
      Logger.log('Error checking permissions: $e');
      return false;
    }
  }static Future<void> openSettings() async {
    Logger.log('Opening app settings');
    await openAppSettings();
  }
}
