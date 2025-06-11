import 'dart:developer' as developer;

class Logger {
  static void log(String message) {
    developer.log(message, name: 'GyroCar');
  }
  
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message, 
      name: 'GyroCar', 
      error: error, 
      stackTrace: stackTrace,
      level: 1000 // Error level
    );
  }
  
  static void warning(String message) {
    developer.log(
      message, 
      name: 'GyroCar', 
      level: 900 // Warning level
    );
  }
  
  static void info(String message) {
    developer.log(
      message, 
      name: 'GyroCar', 
      level: 800 // Info level
    );
  }
}