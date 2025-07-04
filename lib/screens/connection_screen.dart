import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_control_provider.dart';
import '../services/permission_service.dart';
import '../models/bluetooth_device.dart';
import 'control_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '80');
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 40),
              const Text(
                'GyroCar',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect to your car',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF8e8e93),
                ),
              ),
              
              const Spacer(),
              
              // Connection Form
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1c1c1e),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF38383a),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Camera Setup',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // IP Address Field
                    _buildIOSTextField(
                      controller: _ipController,
                      label: 'Camera IP Address',
                      placeholder: '192.168.1.100',
                      icon: Icons.videocam,
                    ),
                    const SizedBox(height: 16),
                    
                    // Port Field
                    _buildIOSTextField(
                      controller: _portController,
                      label: 'Port',
                      placeholder: '80',
                      icon: Icons.settings_ethernet,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    
                    // Error Message
                    if (_errorMessage != null) ...[
                      Container(                        padding: const EdgeInsets.all(12),                        decoration: BoxDecoration(
                          color: const Color(0xFFff3b30).withValues(alpha: 26), // 0.1 opacity (26/255)
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFff3b30).withValues(alpha: 77), // 0.3 opacity (77/255)
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Color(0xFFff3b30),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFff3b30),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    
                    // Connect Button
                    _buildIOSButton(
                      label: _isConnecting ? 'Connecting...' : 'Connect',
                      color: const Color(0xFF007aff),
                      onPressed: _isConnecting ? null : _connectToDevices,
                      isLoading: _isConnecting,
                    ),
                  ],
                ),
              ),
                const Spacer(),
              
              // Footer
              const Text(
                'Enter your ESP32-CAM IP address (local or WAN)',
                style: TextStyle(
                  color: Color(0xFF8e8e93),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'ESP32 should advertise as "GyroCar" via Bluetooth',
                style: TextStyle(
                  color: Color(0xFF8e8e93),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIOSTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8e8e93),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2c2c2e),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF38383a),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: const TextStyle(
                color: Color(0xFF8e8e93),
                fontSize: 16,
              ),
              prefixIcon: Icon(
                icon,
                color: const Color(0xFF8e8e93),
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIOSButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
    bool isLoading = false,
  }) {
    return Container(
      height: 50,      decoration: BoxDecoration(
        color: onPressed != null ? color : color.withValues(alpha: 128), // 0.5 opacity (128/255)
        borderRadius: BorderRadius.circular(25),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(25),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }  Future<void> _connectToDevices() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final provider = Provider.of<CarControlProvider>(context, listen: false);

    try {
      // Validate IP address format
      final ip = _ipController.text.trim();
      if (ip.isEmpty) {
        throw Exception('Please enter a camera IP address');
      }
      
      // Basic IP validation (allow both IPv4 and simple hostnames)
      final ipRegex = RegExp(r'^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
      if (!ipRegex.hasMatch(ip) && !ip.contains('.')) {
        throw Exception('Please enter a valid IP address (e.g., 192.168.1.100)');
      }

      final port = int.tryParse(_portController.text.trim()) ?? 80;

      // First connect to camera
      bool cameraConnected = await provider.connectCamera(ip, port);
      
      if (!cameraConnected) {
        throw Exception('Failed to connect to ESP32-CAM. Please check IP address and ensure camera is online.');
      }

      // Now scan for Bluetooth devices
      final devices = await provider.scanBluetoothDevices();
      
      if (!mounted) return;

      if (devices.isEmpty) {
        // Show a more detailed error with troubleshooting steps
        _showNoDevicesFoundDialog();
        return;
      }

      // Show device selection dialog
      final selectedDevice = await _showDeviceSelectionDialog(devices);
      
      if (selectedDevice != null) {
        // Connect to selected Bluetooth device
        await provider.connectBluetooth(selectedDevice.address);
        
        // Wait a moment for connection to establish
        await Future.delayed(const Duration(seconds: 2));
        
        if (provider.connectionStatus == ConnectionStatus.connected) {
          // Navigate to control screen
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const ControlScreen(),
              ),
            );
          }
        } else {
          throw Exception('Failed to connect to Bluetooth device');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
        });
      }
    }
  }
  Future<BluetoothDevice?> _showDeviceSelectionDialog(List<BluetoothDevice> devices) async {
    return showDialog<BluetoothDevice>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Select Your ESP32 Device',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 300),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [              const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Choose the ESP32 device for your car. Devices are sorted by signal strength.',
                  style: TextStyle(
                    color: Color(0xFF8e8e93),
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Color(0xFF38383a),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    final bool isLikelyESP32 = 
                        device.name.toLowerCase().contains('esp') ||
                        device.name.toLowerCase().contains('gyro') ||
                        device.name.toLowerCase().contains('car') ||
                        device.name.toLowerCase() == 'gyrocar' ||
                        device.address.startsWith('24:6f:28') ||
                        device.address.startsWith('24:0a:c4') ||
                        device.address.startsWith('30:ae:a4') ||
                        device.address.startsWith('8c:aa:b5') ||
                        device.address.startsWith('c8:c9:a3') ||
                        device.address.startsWith('dc:a6:32') ||
                        device.address.startsWith('7c:9e:bd');
                    
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2c2c2e),
                        borderRadius: BorderRadius.circular(8),
                        border: isLikelyESP32 ? Border.all(
                          color: const Color(0xFF34c759),
                          width: 1,
                        ) : null,
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: Stack(
                          children: [
                            Icon(
                              Icons.bluetooth,
                              color: isLikelyESP32 ? const Color(0xFF34c759) : const Color(0xFF007aff),
                              size: 24,
                            ),
                            if (isLikelyESP32)
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 4,
                                  backgroundColor: Color(0xFF34c759),
                                ),
                              ),
                          ],
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                device.name.isNotEmpty ? device.name : 'Unknown Device',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: isLikelyESP32 ? FontWeight.w600 : FontWeight.w500,
                                ),
                              ),
                            ),
                            if (device.signalStrength != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: device.signalStrength == 'Strong' 
                                      ? const Color(0xFF34c759).withValues(alpha: 26)
                                      : device.signalStrength == 'Medium'
                                          ? const Color(0xFFff9500).withValues(alpha: 26)
                                          : const Color(0xFFff3b30).withValues(alpha: 26),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  device.signalStrength!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: device.signalStrength == 'Strong' 
                                        ? const Color(0xFF34c759)
                                        : device.signalStrength == 'Medium'
                                            ? const Color(0xFFff9500)
                                            : const Color(0xFFff3b30),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '${device.address}${device.rssi != null ? ' (${device.rssi} dBm)' : ''}',
                          style: const TextStyle(
                            color: Color(0xFF8e8e93),
                            fontSize: 14,
                          ),
                        ),
                        trailing: isLikelyESP32
                            ? const Text(
                                'ESP32',
                                style: TextStyle(
                                  color: Color(0xFF34c759),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0xFF8e8e93),
                                size: 16,
                              ),
                        onTap: () {
                          Navigator.of(context).pop(device);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Rescan',
              style: TextStyle(
                color: Color(0xFF007aff),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              final devices = await Provider.of<CarControlProvider>(context, listen: false).scanBluetoothDevices();
              if (devices.isNotEmpty) {
                _showDeviceSelectionDialog(devices);
              }
            },
          ),
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF007aff),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showPermissionHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Permissions Required',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'To scan for Bluetooth devices, this app needs:\n\n'
          '• Bluetooth permissions\n'
          '• Location permissions\n\n'
          'Location is required by Android for Bluetooth device scanning.\n\n'
          'Would you like to grant these permissions?',
          style: TextStyle(
            color: Color(0xFF8e8e93),
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Not Now',
              style: TextStyle(
                color: Color(0xFF8e8e93),
                fontSize: 16,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text(
              'Grant Permissions',
              style: TextStyle(
                color: Color(0xFF007aff),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () async {
              Navigator.of(context).pop();
              bool granted = await PermissionService.requestBluetoothPermissions();
              if (granted) {
                _scanAndShowDevices();
              } else {
                _showPermissionDeniedDialog();
              }
            },
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Permissions Denied',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Bluetooth and location permissions are required to scan for devices.\n\n'
          'Please enable them in your app settings to continue.',
          style: TextStyle(
            color: Color(0xFF8e8e93),
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8e8e93),
                fontSize: 16,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text(
              'Open Settings',
              style: TextStyle(
                color: Color(0xFF007aff),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),            onPressed: () async {
              Navigator.of(context).pop();
              await PermissionService.openSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _scanAndShowDevices() async {
    try {
      final provider = Provider.of<CarControlProvider>(context, listen: false);
      final devices = await provider.scanBluetoothDevices();
      
      if (devices.isEmpty) {
        _showNoDevicesFoundDialog();
      } else {
        _showDeviceSelectionDialog(devices);
      }
    } catch (e) {
      if (e.toString().contains('permission')) {
        _showPermissionHelpDialog();
      } else {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }
  void _showNoDevicesFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'No Devices Found',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const SingleChildScrollView(
          child: Text(
            'No Bluetooth devices were found.\n\n'
            'Troubleshooting Steps:\n\n'
            '1. Make sure your ESP32 car is powered on\n'
            '2. Ensure ESP32 is advertising as "GyroCar"\n'
            '3. Check that Location services are enabled in Android Settings\n'
            '4. Verify Bluetooth is enabled and working\n'
            '5. Try manually pairing the device in Android Settings first\n'
            '6. Move closer to the ESP32 device (within 10 meters)\n'
            '7. Restart the ESP32 and try again\n'
            '8. Clear Bluetooth cache in Android Settings > Apps > Bluetooth\n\n'
            'If the device appears in Android Bluetooth settings but not here, '
            'there may be a permission issue.',
            style: TextStyle(
              color: Color(0xFF8e8e93),
              fontSize: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Check Permissions',
              style: TextStyle(
                color: Color(0xFF007aff),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showPermissionHelpDialog();
            },
          ),
          TextButton(
            child: const Text(
              'Try Again',
              style: TextStyle(
                color: Color(0xFF007aff),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _scanAndShowDevices();
            },
          ),
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF8e8e93),
                fontSize: 16,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
