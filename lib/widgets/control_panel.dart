import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/car_control_provider.dart';
import '../utils/constants.dart';

class ControlPanel extends StatelessWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CarControlProvider>(context);
    final isConnected = provider.connectionStatus == ConnectionStatus.connected;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      color: AppColors.primaryColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Car Controls',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.secondaryColor,
              ),
            ),
            const SizedBox(height: 24),
            
            // Start/Stop Button
            Center(
              child: GestureDetector(
                onTap: isConnected ? provider.toggleControl : null,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isConnected 
                        ? provider.isControlActive 
                            ? Colors.red 
                            : AppColors.accentColor
                        : Colors.grey,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.3 * 255).round()),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      provider.isControlActive ? Icons.stop : Icons.play_arrow,
                      size: 48,
                      color: AppColors.secondaryColor,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Sensitivity Slider
            Text(
              'Gyroscope Sensitivity',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.secondaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.speed_outlined, color: AppColors.secondaryColor),
                Expanded(
                  child: Slider(
                    value: provider.sensitivity,
                    min: 0.1,
                    max: 3.0,
                    divisions: 29,
                    label: provider.sensitivity.toStringAsFixed(1),
                    onChanged: isConnected ? (value) => provider.setSensitivity(value) : null,
                  ),
                ),
                const Icon(Icons.speed, color: AppColors.secondaryColor),
              ],
            ),
            const SizedBox(height: 16),
              // Current values display
            if (provider.isControlActive) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryColor.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Gyroscope Values:',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.secondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),                    Text(
                      'X: ${(provider.lastControlData['x']! * provider.sensitivity).toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.secondaryColor),
                    ),
                    Text(
                      'Y: ${(provider.lastControlData['y']! * provider.sensitivity).toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.secondaryColor),
                    ),
                    Text(
                      'Z: ${(provider.lastControlData['z'] ?? 0.0 * provider.sensitivity).toStringAsFixed(2)}',
                      style: const TextStyle(color: AppColors.secondaryColor),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
