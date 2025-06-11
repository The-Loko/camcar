import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui'; // Add this for FontFeature
import '../providers/car_control_provider.dart';
import '../services/connection_service.dart';
import '../widgets/mjpeg_viewer.dart';
import '../widgets/joystick.dart';
import 'connection_screen.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  bool _isPowerOn = false;
  bool _isAutoMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Consumer<CarControlProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                // Header with disconnect button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'GyroCar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => _showDisconnectDialog(),
                        icon: const Icon(
                          Icons.settings,
                          color: Color(0xFF8e8e93),
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),

                // Video Section
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1c1c1e),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF38383a),
                        width: 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: provider.cameraUrl.isNotEmpty
                                ? MjpegViewer(
                                    isLive: true,
                                    stream: provider.cameraUrl,
                                  )
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.videocam_off,
                                          color: Color(0xFF8e8e93),
                                          size: 48,
                                        ),
                                        SizedBox(height: 12),
                                        Text(
                                          'Camera feed loading...',
                                          style: TextStyle(
                                            color: Color(0xFF8e8e93),
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                        
                        // Status indicators
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Row(
                            children: [
                              _buildStatusDot(
                                isActive: provider.cameraUrl.isNotEmpty,
                                label: 'CAM',
                              ),
                              const SizedBox(width: 8),
                              _buildStatusDot(
                                isActive: provider.connectionStatus == ConnectionStatus.connected,
                                label: 'BT',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Sensor Data Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1c1c1e),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF38383a),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSensorDisplay(
                        icon: Icons.social_distance,
                        label: 'Distance',
                        value: '${provider.sensorData.distance.toStringAsFixed(1)} cm',
                        color: provider.sensorData.distance < 20 
                            ? const Color(0xFFff3b30) 
                            : const Color(0xFF34c759),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: const Color(0xFF38383a),
                      ),
                      _buildSensorDisplay(
                        icon: Icons.thermostat,
                        label: 'Temp',
                        value: '${provider.sensorData.temperature.toStringAsFixed(1)}°C',
                        color: const Color(0xFF007aff),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: const Color(0xFF38383a),
                      ),
                      _buildSensorDisplay(
                        icon: Icons.water_drop,
                        label: 'Humidity',
                        value: '${provider.sensorData.humidity.toStringAsFixed(1)}%',
                        color: const Color(0xFF007aff),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Controls Section
                Expanded(
                  flex: 2,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        // Joystick
                        Expanded(
                          child: Center(
                            child: Joystick(
                              size: 140,
                              onChanged: (x, y) {
                                if (_isPowerOn && !_isAutoMode) {
                                  provider.sendJoystickData(x, y);
                                }
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 20),
                        
                        // Control Buttons
                        Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildControlButton(
                              label: _isPowerOn ? 'ON' : 'OFF',
                              color: _isPowerOn 
                                  ? const Color(0xFF34c759) 
                                  : const Color(0xFFff3b30),
                              onPressed: () {
                                setState(() {
                                  _isPowerOn = !_isPowerOn;
                                });
                                provider.sendPowerCommand(_isPowerOn);
                              },
                            ),
                            
                            _buildControlButton(
                              label: _isAutoMode ? 'AUTO' : 'MANUAL',
                              color: _isAutoMode 
                                  ? const Color(0xFFff9500) 
                                  : const Color(0xFF007aff),
                              onPressed: _isPowerOn ? () {
                                setState(() {
                                  _isAutoMode = !_isAutoMode;
                                });
                                provider.sendModeCommand(_isAutoMode ? 'auto' : 'manual');
                              } : null,
                            ),
                            
                            _buildControlButton(
                              label: 'DISCONNECT',
                              color: const Color(0xFFff3b30),
                              onPressed: () => _showDisconnectDialog(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusDot({required bool isActive, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 153), // 0.6 opacity (153/255)
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive 
                  ? const Color(0xFF34c759) 
                  : const Color(0xFFff3b30),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorDisplay({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            value,            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8e8e93),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required String label,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 80,
      height: 44,      decoration: BoxDecoration(
        color: onPressed != null ? color : color.withValues(alpha: 128), // 0.5 opacity (128/255)
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1c1c1e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Disconnect',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Are you sure you want to disconnect from the car?',
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
                color: Color(0xFF007aff),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text(
              'Disconnect',
              style: TextStyle(
                color: Color(0xFFff3b30),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _disconnect();
            },
          ),
        ],
      ),
    );
  }

  void _disconnect() {
    final provider = Provider.of<CarControlProvider>(context, listen: false);
    provider.disconnect();
    
    // Reset local state
    setState(() {
      _isPowerOn = false;
      _isAutoMode = false;
    });
    
    // Navigate back to connection screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const ConnectionScreen(),
      ),
    );
  }
}
