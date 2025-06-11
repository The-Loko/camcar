import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_control_provider.dart';
import '../widgets/connection_panel.dart';
import '../utils/constants.dart';
import '../widgets/mjpeg_viewer.dart';
import '../widgets/joystick.dart';
import '../services/connection_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key}); // Use super parameter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GyroCar'),
        centerTitle: true,
        backgroundColor: AppColors.primaryColor,
      ),
      body: Consumer<CarControlProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,              children: [
                const ConnectionPanel(),
                const SizedBox(height: 16),
                // Video Section
                if (provider.cameraUrl.isNotEmpty) ...[
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: MjpegViewer(
                          isLive: true,
                          stream: provider.cameraUrl,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Parameters Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ParameterItem(label: 'Distance',
                        value: provider.sensorData?.distance.toStringAsFixed(1) ?? '--',),
                      _ParameterItem(label: 'Temp (°C)',
                        value: provider.sensorData?.temperature.toStringAsFixed(1) ?? '--',),
                      _ParameterItem(label: 'Humidity (%)',
                        value: provider.sensorData?.humidity.toStringAsFixed(1) ?? '--',),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Controls Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Joystick(
                      size: 150,
                      onChanged: (x, y) {
                        provider.sendJoystick(x, y);
                      },
                    ),
                    Column(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(24),
                            backgroundColor: provider.isPowerOn ? Colors.red : Colors.grey,
                          ),
                          onPressed: provider.togglePower,
                          child: const Icon(Icons.power_settings_new, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(24),
                            backgroundColor: provider.isAutoMode ? Colors.green : Colors.grey,
                          ),
                          onPressed: provider.toggleMode,
                          child: const Icon(Icons.autorenew, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Status Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StatusDot(active: provider.isPowerOn),
                    _StatusDot(active: provider.isAutoMode),
                    _StatusDot(active: provider.connectionStatus == ConnectionStatus.connected),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ParameterItem extends StatelessWidget {
  final String label;
  final String value;

  const _ParameterItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;

  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: active ? Colors.green : Colors.red,
        shape: BoxShape.circle,
      ),
    );
  }
}
