import 'package:permission_handler/permission_handler.dart';
import '../utils/logger.dart';

class PermissionService {
  static Future<bool> requestBluetoothPermissions() async {
    Logger.log('Requesting Bluetooth and location permissions');
    
    try {
      // List of required permissions for Bluetooth operations
      final permissions = <Permission>[
        Permission.bluetooth,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
        Permission.locationWhenInUse,
      ];
      
      // Check current permission status
      Map<Permission, PermissionStatus> statuses = await permissions.request();
      
      // Log permission statuses
      for (var entry in statuses.entries) {
        Logger.log('${entry.key.toString()}: ${entry.value.toString()}');
      }
      
      // Check if all critical permissions are granted
      bool bluetoothGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
      bool bluetoothScanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      bool bluetoothConnectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      bool locationGranted = statuses[Permission.location]?.isGranted ?? false || 
                            statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      
      // For older Android versions, only bluetooth and location are needed
      bool allGranted = (bluetoothGranted || bluetoothScanGranted) && 
                       (bluetoothConnectGranted || bluetoothGranted) && 
                       locationGranted;
      
      if (allGranted) {
        Logger.log('All Bluetooth permissions granted');
        return true;
      } else {
        Logger.log('Some Bluetooth permissions denied');
        
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
        Permission.location,
        Permission.locationWhenInUse,
      ];
      
      Map<Permission, PermissionStatus> statuses = {};
      for (var permission in permissions) {
        statuses[permission] = await permission.status;
      }
      
      bool bluetoothGranted = statuses[Permission.bluetooth]?.isGranted ?? false;
      bool bluetoothScanGranted = statuses[Permission.bluetoothScan]?.isGranted ?? false;
      bool bluetoothConnectGranted = statuses[Permission.bluetoothConnect]?.isGranted ?? false;
      bool locationGranted = statuses[Permission.location]?.isGranted ?? false || 
                            statuses[Permission.locationWhenInUse]?.isGranted ?? false;
      
      return (bluetoothGranted || bluetoothScanGranted) && 
             (bluetoothConnectGranted || bluetoothGranted) && 
             locationGranted;
    } catch (e) {
      Logger.log('Error checking permissions: $e');
      return false;
    }
  }  static Future<void> openSettings() async {
    Logger.log('Opening app settings');
    await openAppSettings();
  }
}
