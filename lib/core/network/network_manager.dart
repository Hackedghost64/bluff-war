import 'dart:async';

abstract class NetworkManager {
  Future<void> initialize();
  Future<void> dispose();
  
  Future<void> sendPacket(Map<String, dynamic> payload);
  Stream<Map<String, dynamic>> get incomingPackets;
}
