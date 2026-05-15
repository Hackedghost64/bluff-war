import 'dart:math';

class BleProtocol {
  static const String bluffServiceUuid = 'b1uff000-0000-1000-8000-00805f9b34fb';
  static const String bluffCharUuid = 'b1uff001-0000-1000-8000-00805f9b34fb';

  static Map<String, dynamic> createPacket(
    String type, {
    Map<String, dynamic> data = const {},
  }) {
    return {
      'version': 1,
      'type': type,
      'id': _generatePacketId(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    };
  }

  static String _generatePacketId() {
    final random = Random();
    const chars = 'abcdef0123456789';
    return List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
