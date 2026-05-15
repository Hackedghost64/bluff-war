import 'dart:async';

enum LogLevel { info, warning, error, critical, transition }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogLevel level;
  final dynamic error;

  LogEntry({
    required this.timestamp,
    required this.message,
    required this.level,
    this.error,
  });

  @override
  String toString() {
    final errStr = error != null ? ' ($error)' : '';
    return '[${level.name.toUpperCase()}] ${timestamp.toIso8601String()}: $message$errStr';
  }
}

class NetLogger {
  static final StreamController<LogEntry> _logController = StreamController<LogEntry>.broadcast();
  static Stream<LogEntry> get logStream => _logController.stream;

  static void log(String message) {
    _emit(message, LogLevel.info);
  }

  static void info(String message) {
    _emit(message, LogLevel.info);
  }

  static void warning(String message) {
    _emit(message, LogLevel.warning);
  }

  static void error(String message, [dynamic error]) {
    _emit(message, LogLevel.error, error: error);
  }

  static void critical(String message, [dynamic error]) {
    _emit(message, LogLevel.critical, error: error);
  }

  static void transition(String message) {
    _emit(message, LogLevel.transition);
  }

  static void _emit(String message, LogLevel level, {dynamic error}) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      message: message,
      level: level,
      error: error,
    );
    // ignore: avoid_print
    print(entry.toString());
    
    if (!_logController.isClosed) {
      _logController.add(entry);
    }
  }

  static void dispose() {
    _logController.close();
  }
}
