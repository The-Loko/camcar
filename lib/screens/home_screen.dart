import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_control_provider.dart';
import '../widgets/connection_panel.dart';
import '../utils/constants.dart';
import '../widgets/mjpeg_viewer.dart';
import '../widgets/joystick.dart';
import '../services/connection_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('GyroCar'),
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
      ),
      body: Consumer<CarControlProvider>(
        builder: (context, provider, child) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Video Section with status dots
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(16),
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
                                  )                                : Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          AppColors.surfaceColor,
                                          AppColors.secondaryColor,
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Camera Feed',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        // Status dots in top-right corner
                        Positioned(
                          top: 16,
                          right: 16,                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _StatusDot(
                                active: provider.connectionStatus == ConnectionStatus.connected,
                              ),
                              const SizedBox(width: 8),
                              _StatusDot(active: provider.isPowerOn),
                              const SizedBox(width: 8),
                              _StatusDot(active: provider.isAutoMode),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Parameters Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ParameterItem(
                      label: 'Distance',
                      value: provider.sensorData?.distance.toStringAsFixed(1) ?? '--',
                      unit: 'm',
                    ),
                    _ParameterItem(
                      label: 'Temperature',
                      value: provider.sensorData?.temperature.toStringAsFixed(1) ?? '--',
                      unit: '°C',
                    ),
                    _ParameterItem(
                      label: 'Humidity',
                      value: provider.sensorData?.humidity.toStringAsFixed(1) ?? '--',
                      unit: '%',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Controls Section
                Expanded(
                  flex: 2,
                  child: Row(
                    children: [
                      // Joystick
                      Expanded(
                        child: Center(
                          child: Joystick(
                            size: 140,
                            onChanged: (x, y) {
                              provider.sendJoystick(x, y);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 30),
                      
                      // Control Buttons
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _ControlButton(
                            label: provider.isPowerOn ? 'ON' : 'OFF',
                            isActive: provider.isPowerOn,
                            activeColor: AppColors.systemGreen,
                            inactiveColor: AppColors.systemRed,
                            onPressed: provider.togglePower,
                          ),
                          const SizedBox(height: 12),
                          _ControlButton(
                            label: provider.isAutoMode ? 'Auto' : 'Manual',
                            isActive: provider.isAutoMode,
                            activeColor: AppColors.systemOrange,
                            inactiveColor: AppColors.systemBlue,
                            onPressed: provider.toggleMode,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Connection Panel at bottom
                const ConnectionPanel(),
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
  final String unit;

  const _ParameterItem({
    required this.label,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$value$unit',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {},
      onTapUp: (_) => onPressed(),
      onTapCancel: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 80,
        height: 44,
        decoration: BoxDecoration(
          color: isActive ? activeColor : inactiveColor,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final bool active;

  const _StatusDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.systemGreen : AppColors.systemRed,
        shape: BoxShape.circle,
      ),
    );
  }
}
