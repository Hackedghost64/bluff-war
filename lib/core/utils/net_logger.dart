class NetLogger {
  static void log(String message) {
    print('[NET] ${DateTime.now().toIso8601String()}: $message');
  }

  static void error(String message, [dynamic error]) {
    print('[NET_ERROR] ${DateTime.now().toIso8601String()}: $message ${error != null ? '($error)' : ''}');
  }

  static void critical(String message, [dynamic error]) {
    print('[NET_CRITICAL] ${DateTime.now().toIso8601String()}: $message ${error != null ? '($error)' : ''}');
  }
}
