// filepath: d:\Devs\Nihal\camcar\lib\models\sensor_data.dart
class SensorData {
  final double? distance;
  final double? temperature;
  final double? humidity;
  final DateTime? timestamp;

  SensorData({
    this.distance,
    this.temperature,
    this.humidity,
    this.timestamp,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      distance: (json['distance'] as num?)?.toDouble(),
      temperature: (json['temperature'] as num?)?.toDouble(),
      humidity: (json['humidity'] as num?)?.toDouble(),
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'distance': distance,
      'temperature': temperature,
      'humidity': humidity,
      'timestamp': timestamp?.toIso8601String(),
    };
  }
}
