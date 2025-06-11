import 'package:wifi_scan/wifi_scan.dart';

class WiFiNetwork {
  final String ssid;
  final String bssid;
  final int signalStrength;

  WiFiNetwork({
    required this.ssid,
    required this.bssid,
    required this.signalStrength,
  });

  factory WiFiNetwork.fromWiFiAccessPoint(WiFiAccessPoint accessPoint) {
    return WiFiNetwork(
      ssid: accessPoint.ssid,
      bssid: accessPoint.bssid,
      signalStrength: accessPoint.level,
    );
  }
}
