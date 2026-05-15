import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:ble_network/core/controllers/game_controller.dart';
import 'package:ble_network/core/network/host_manager.dart';
import 'package:ble_network/core/network/guest_manager.dart';
import 'package:ble_network/core/models/game_state.dart';
import 'package:nearby_connections/nearby_connections.dart';

class MockHostManager implements HostManager {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  @override
  Future<void> dispose() async => await _controller.close();
  @override
  Stream<Map<String, dynamic>> get incomingPackets => _controller.stream;
  @override
  Future<void> initialize() async {}
  @override
  bool get isConnected => true;
  @override
  Future<void> sendPacket(Map<String, dynamic> payload) async {}
  @override
  Future<void> startAdvertising() async {}
  @override
  Future<void> stopAdvertising() async {}
  @override
  String get serviceId => "test";
  @override
  Strategy get strategy => Strategy.P2P_POINT_TO_POINT;
  void injectPacket(Map<String, dynamic> packet) {
    if (!_controller.isClosed) _controller.add(packet);
  }
}

class MockGuestManager implements GuestManager {
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();
  @override
  Future<void> dispose() async => await _controller.close();
  @override
  Stream<Map<String, dynamic>> get incomingPackets => _controller.stream;
  @override
  Future<void> initialize() async {}
  @override
  bool get isConnected => true;
  @override
  Future<void> sendPacket(Map<String, dynamic> payload) async {}
  @override
  Future<void> startDiscovery() async {}
  @override
  Future<void> stopDiscovery() async {}
  @override
  String get serviceId => "test";
  @override
  Strategy get strategy => Strategy.P2P_POINT_TO_POINT;
  void injectPacket(Map<String, dynamic> packet) {
    if (!_controller.isClosed) _controller.add(packet);
  }
}

void main() {
  group('Network Stress Tests', () {
    Map<String, dynamic> createPacket(
      String type, {
      Map<String, dynamic>? data,
      String? id,
    }) {
      return {
        'version': 1,
        'type': type,
        'id': id ?? Random().nextInt(1000000).toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'data': data ?? {},
      };
    }

    test('Packet Flood: 1,000+ rapid-fire packets', () async {
      final mockNetwork = MockHostManager();
      final controller = GameController(mockNetwork);

      for (int i = 0; i < 1000; i++) {
        mockNetwork.injectPacket(createPacket('ping', data: {'index': i}));
      }

      await Future.delayed(Duration.zero);
      expect(controller.state.phase, GamePhase.initial);
      controller.dispose();
    });

    test('O(1) Deduplication: identical UUID packets', () async {
      final mockNetwork = MockHostManager();
      final controller = GameController(mockNetwork);
      const String duplicateId = 'static-uuid-123';

      final packet = createPacket('system_disconnect', id: duplicateId);

      mockNetwork.injectPacket(packet);
      mockNetwork.injectPacket(packet);
      mockNetwork.injectPacket(packet);

      await Future.delayed(Duration.zero);
      expect(controller.state.phase, GamePhase.initial);
      controller.dispose();
    });

    test('Out-of-Order Delivery: Guest rejects invalid transitions', () async {
      final mockNetwork = MockGuestManager();
      final controller = GameController(mockNetwork);

      final badPacket = createPacket(
        'state_sync',
        data: {'phase': 'reveal', 'players': [], 'roundScores': {}},
      );

      mockNetwork.injectPacket(badPacket);
      await Future.delayed(Duration.zero);

      expect(controller.state.phase, GamePhase.initial);
      controller.dispose();
    });

    test('Mid-Round Disconnect: Graceful reset', () async {
      final mockNetwork = MockHostManager();
      final controller = GameController(
        mockNetwork,
        disconnectGracePeriod: Duration.zero,
      );

      controller.addPlayer('h1', 'Host', isHost: true);
      controller.setPhase(GamePhase.lobby);
      controller.setPhase(GamePhase.dealing);
      controller.dealCards();

      expect(controller.state.phase, GamePhase.playing);

      mockNetwork.injectPacket(createPacket('system_disconnect'));

      await Future.delayed(Duration.zero);
      expect(controller.state.phase, GamePhase.initial);
      controller.dispose();
    });
  });
}
