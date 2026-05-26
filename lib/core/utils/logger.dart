import '../../config/app_config.dart';

/// Simple logger utility
class AppLogger {
  final String _tag;

  AppLogger(this._tag);

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (AppConfig.isDevelopment) {
      print('[DEBUG][$_tag] $message');
      if (error != null) print('Error: $error');
      if (stackTrace != null) print('Stack: $stackTrace');
    }
  }

  void info(String message) {
    print('[INFO][$_tag] $message');
  }

  void warning(String message, [Object? error]) {
    print('[WARNING][$_tag] $message');
    if (error != null) print('Error: $error');
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR][$_tag] $message');
    if (error != null) print('Error: $error');
    if (stackTrace != null) print('Stack: $stackTrace');
  }
}

