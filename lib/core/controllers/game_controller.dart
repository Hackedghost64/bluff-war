import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../network/network_manager.dart';
import '../utils/net_logger.dart';

class GameController extends ChangeNotifier {
  final NetworkManager _network;
  GameState _state = const GameState();

  GameController(this._network) {
    _network.incomingPackets.listen(_handleIncomingPacket);
  }

  GameState get state => _state;

  void _handleIncomingPacket(Map<String, dynamic> packet) {
    try {
      final type = packet['type'] as String;
      final data = packet['data'] as Map<String, dynamic>;

      switch (type) {
        case 'state_sync':
          _state = GameState.fromJson(data);
          notifyListeners();
          break;
        case 'player_joined':
          final newPlayer = Player.fromJson(data);
          _addPlayerLocally(newPlayer);
          break;
        // Add more packet types as needed for Jump 3+
      }
    } catch (e) {
      NetLogger.error('Controller failed to handle packet', e);
    }
  }

  // --- UI Intents ---

  void setPhase(GamePhase phase) {
    _state = _state.copyWith(phase: phase);
    notifyListeners();
    _broadcastState();
  }

  void addPlayer(String id, String name, {bool isHost = false}) {
    final player = Player(id: id, displayName: name, isHost: isHost);
    _addPlayerLocally(player);
    _broadcastState();
  }

  // --- Internal Mutations ---

  void _addPlayerLocally(Player player) {
    if (!_state.players.any((p) => p.id == player.id)) {
      _state = _state.copyWith(
        players: [..._state.players, player],
      );
      notifyListeners();
    }
  }

  void _broadcastState() {
    _network.sendPacket({
      'type': 'state_sync',
      'data': _state.toJson(),
    });
  }

  @override
  void dispose() {
    _network.dispose();
    super.dispose();
  }
}
