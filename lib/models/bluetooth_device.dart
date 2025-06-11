class BluetoothDevice {
  final String name;
  final String address;
  final int? rssi;
  final String? signalStrength;

  BluetoothDevice({
    required this.name,
    required this.address,
    this.rssi,
    this.signalStrength,
  });

  factory BluetoothDevice.fromFlutterBluetoothSerial(dynamic device) {
    return BluetoothDevice(
      name: device.name ?? 'Unknown Device',
      address: device.address,
    );
  }
}
