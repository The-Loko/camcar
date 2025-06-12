class SensorData {
  final double distance;
  final double temperature;
  final double humidity;
  final DateTime timestamp;

  SensorData({
    this.distance = 0.0,
    this.temperature = 0.0,
    this.humidity = 0.0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
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
