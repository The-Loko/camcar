import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_control_provider.dart';
import '../services/connection_service.dart';
import '../utils/constants.dart';
import '../models/bluetooth_device.dart';

class ConnectionPanel extends StatefulWidget {
  const ConnectionPanel({super.key});

  @override
  State<ConnectionPanel> createState() => _ConnectionPanelState();
}

class _ConnectionPanelState extends State<ConnectionPanel> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _portController = TextEditingController(text: '80');

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CarControlProvider>(context);
    final isConnected = provider.connectionStatus == ConnectionStatus.connected;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1e), // iOS dark background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF38383a),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          Text(
            'Connection',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 20),
          
          // Connection Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2c2c2e),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected 
                        ? const Color(0xFF34c759) // iOS green
                        : const Color(0xFFff3b30), // iOS red
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _getStatusText(provider.connectionStatus),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (provider.connectionStatus == ConnectionStatus.connecting)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007aff)),
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Bluetooth Section
          if (!isConnected) ...[
            _buildIOSButton(
              label: 'Scan for Devices',
              color: const Color(0xFF007aff), // iOS blue
              onPressed: () async {
                final devices = await provider.scanBluetoothDevices();
                if (!mounted) return;
                _showDeviceSelectionDialog(devices);
              },
            ),
            const SizedBox(height: 12),
          ],
          
          // WiFi Section for Camera
          if (provider.connectionType != ConnectionType.bluetooth) ...[
            _buildIOSTextField(
              controller: _ipController,
              label: 'Camera IP Address',
              placeholder: '192.168.1.100',
            ),
            const SizedBox(height: 12),
            _buildIOSTextField(
              controller: _portController,
              label: 'Port',
              placeholder: '80',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            _buildIOSButton(
              label: 'Connect Camera',
              color: const Color(0xFF007aff),
              onPressed: () {
                final ip = _ipController.text.trim();
                final port = int.tryParse(_portController.text.trim()) ?? 80;
                provider.connectWifi(ip, port);
              },
            ),
            const SizedBox(height: 20),
          ],
          
          // Main Action Button
          _buildIOSButton(
            label: isConnected ? 'Disconnect' : 'Connect',
            color: isConnected 
                ? const Color(0xFFff3b30) // iOS red
                : const Color(0xFF34c759), // iOS green
            onPressed: () async {
              if (isConnected) {
                provider.disconnect();
              } else {
                final devices = await provider.scanBluetoothDevices();
                if (!mounted) return;
                _showDeviceSelectionDialog(devices);
              }
            },
          ),
        ],
      ),
    );  }
  
  String _getStatusText(ConnectionStatus status) {
    switch (status) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.error:
        return 'Connection Error';
      case ConnectionStatus.disconnected:
      default:
        return 'Disconnected';
    }
  }
  
  Widget _buildIOSButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onPressed,
          child: Center(
            child: Text(
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
  }
  
  Widget _buildIOSTextField({
    required TextEditingController controller,
    required String label,
    required String placeholder,
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

    // Helper method to show device selection dialog  void _showDeviceSelectionDialog(List<BluetoothDevice> devices) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Select Device',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 300),
          child: devices.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No devices found',
                    style: TextStyle(
                      color: Color(0xFF8e8e93),
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: devices.length,
                  separatorBuilder: (context, index) => Divider(
                    color: const Color(0xFF38383a),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final device = devices[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2c2c2e),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        title: Text(
                          device.name.isNotEmpty ? device.name : 'Unknown Device',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          device.address,
                          style: const TextStyle(
                            color: Color(0xFF8e8e93),
                            fontSize: 14,
                          ),
                        ),
                        trailing: const Icon(
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
        actions: [
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
      ),    ).then((selectedDevice) {
      // Guard context use after async gap (dialog closing)
      if (!mounted || selectedDevice == null) return; 
      
      Provider.of<CarControlProvider>(context, listen: false)
        .connectBluetooth(selectedDevice.address);
    });
  }
}
