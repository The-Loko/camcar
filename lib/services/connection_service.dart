import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../utils/logger.dart';

enum ConnectionStatus { connected, disconnected, connecting, error }

class ConnectionService {
  static ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;
  static String _errorMessage = '';
  static String _cameraUrl = '';

  // Getters
  static ConnectionStatus get connectionStatus => _connectionStatus;
  static String get errorMessage => _errorMessage;
  static String get cameraUrl => _cameraUrl;
  static bool get isConnected => _connectionStatus == ConnectionStatus.connected;  /// Test ESP32-CAM WiFi connection and validate stream
  static Future<bool> testCameraConnection(String ipAddress, int port) async {
    _connectionStatus = ConnectionStatus.connecting;
    _errorMessage = '';
    
    try {
      Logger.log('Testing ESP32-CAM connection at $ipAddress:$port');
      
      // Create HTTP client with timeout
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5)
        ..idleTimeout = const Duration(seconds: 5);
      
      // Test the stream endpoint
      final streamUri = Uri.parse('http://$ipAddress:$port/stream');
      
      try {
        final request = await client.getUrl(streamUri);
        final response = await request.close().timeout(const Duration(seconds: 5));
        
        if (response.statusCode == 200) {
          // Check content type
          final contentType = response.headers.contentType?.toString() ?? '';
          Logger.log('Stream content type: $contentType');
          
          if (contentType.contains('multipart') || 
              contentType.contains('image') ||
              contentType.contains('video')) {
            
            // Successfully connected
            _cameraUrl = 'http://$ipAddress:$port/stream';
            _connectionStatus = ConnectionStatus.connected;
            Logger.log('Successfully connected to ESP32-CAM stream');
            
            // Close the response to avoid memory leaks
            await response.drain();
            return true;
          } else {
            throw Exception('Invalid stream content type: $contentType');
          }
        } else {
          throw Exception('HTTP Error ${response.statusCode}: Could not access camera stream');
        }
      } finally {
        client.close(force: true);
      }
      
    } catch (e) {
      _errorMessage = e.toString();
      _connectionStatus = ConnectionStatus.error;
      _cameraUrl = '';
      Logger.log('Camera connection error: $_errorMessage');
      return false;
    }
  }

  /// Get the MJPEG stream URL for the camera
  static String getMjpegStreamUrl() {
    return _cameraUrl;
  }

  /// Disconnect from camera
  static void disconnect() {
    _connectionStatus = ConnectionStatus.disconnected;
    _errorMessage = '';
    _cameraUrl = '';
    Logger.log('Disconnected from camera');
  }

  /// Check if camera URL is valid format
  static bool isValidCameraUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https');
    } catch (e) {
      return false;
    }
  }
}
