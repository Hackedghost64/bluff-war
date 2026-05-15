import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../network/network_manager.dart';
import '../network/host_manager.dart';
import '../services/audio_service.dart';
import '../utils/net_logger.dart';

class GameController extends ChangeNotifier {
  final NetworkManager _network;
  final Duration _disconnectGracePeriod;
  GameState _state = const GameState();
  String? _localPlayerId;
  String? _localPlayerName;

  final Set<String> _processedPacketIds = {};
  final List<String> _packetIdHistory = [];
  late final StreamSubscription<Map<String, dynamic>>
  _incomingPacketSubscription;

  GameController(
    this._network, {
    Duration disconnectGracePeriod = const Duration(seconds: 30),
  }) : _disconnectGracePeriod = disconnectGracePeriod {
    _incomingPacketSubscription = _network.incomingPackets.listen(
      _handleIncomingPacket,
    );
  }

  GameState get state => _state;
  String? get localPlayerId => _localPlayerId;
  bool get isHost => _network is HostManager;

  void setLocalPlayerId(String id) {
    _localPlayerId = id;
    notifyListeners();
  }

  void setLocalPlayerName(String name) {
    _localPlayerName = name;
  }

  void _handleIncomingPacket(Map<String, dynamic> packet) {
    try {
      if (!_isValidSchema(packet)) return;

      final String packetId = packet['id'] as String;
      if (_processedPacketIds.contains(packetId)) return;
      _markPacketAsProcessed(packetId);

      final type = packet['type'] as String;
      final data = packet['data'] as Map<String, dynamic>;

      if (type == 'system_disconnect') {
        _handleSystemDisconnect();
      } else if (type == 'system_connected') {
        _handleSystemConnected();
      } else if (isHost) {
        _handleHostIntents(type, data);
      } else {
        _handleGuestUpdates(type, data);
      }
    } catch (e) {
      NetLogger.error('Controller failed to handle packet', e);
    }
  }

  void _handleSystemConnected() {
    if (isHost) {
      _broadcastState();
    } else {
      addPlayer(
        'guest_${Random().nextInt(1000)}',
        _localPlayerName ?? 'Player 2',
      );
    }
  }

  Timer? _reconnectTimer;

  void _handleSystemDisconnect() {
    _reconnectTimer?.cancel();
    if (_disconnectGracePeriod == Duration.zero) {
      _resetStateToInitial();
      return;
    }
    _reconnectTimer = Timer(_disconnectGracePeriod, () {
      _resetStateToInitial();
    });
  }

  void _resetStateToInitial() {
    _state = GameState.initial();
    notifyListeners();
  }

  void _handleHostIntents(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'play_card_intent':
        final card = Card.fromJson(data['card'] as Map<String, dynamic>);
        final declaredValue = data['declaredValue'] as int;
        playCard(card, declaredValue);
        break;
      case 'challenge_intent':
        submitChallenge();
        break;
      case 'believe_intent':
        submitBelieve();
        break;
      case 'player_joined_intent':
        final newPlayer = Player.fromJson(data);
        _addPlayerLocally(newPlayer);
        _broadcastState();
        break;
      case 'reset_intent':
        resetGame();
        break;
    }
  }

  void _handleGuestUpdates(String type, Map<String, dynamic> data) {
    if (type == 'state_sync') {
      final newState = GameState.fromJson(data);
      _state = newState;
      notifyListeners();
    }
  }

  bool _isValidSchema(Map<String, dynamic> packet) {
    return packet.containsKey('type') && packet.containsKey('id') && packet.containsKey('data');
  }

  void _markPacketAsProcessed(String id) {
    if (_processedPacketIds.length >= 100) {
      final oldestId = _packetIdHistory.removeAt(0);
      _processedPacketIds.remove(oldestId);
    }
    _processedPacketIds.add(id);
    _packetIdHistory.add(id);
  }

  // --- UI Intents ---

  void resetGame() {
    if (!isHost) {
      _sendIntent('reset_intent', {});
      return;
    }
    _state = GameState.initial().copyWith(
      phase: GamePhase.lobby,
      players: _state.players.map((p) => p.copyWith(hp: 5, hand: [])).toList(),
    );
    notifyListeners();
    _broadcastState();
  }

  void setPhase(GamePhase phase) {
    if (!isHost) return;
    _state = _state.copyWith(phase: phase);
    notifyListeners();
    _broadcastState();
    if (phase == GamePhase.dealing) dealCards();
  }

  void addPlayer(String id, String name, {bool isHost = false}) {
    _localPlayerId ??= id;
    if (this.isHost) {
      final player = Player(id: id, displayName: name, isHost: isHost, hp: 5, hand: []);
      _addPlayerLocally(player);
      _broadcastState();
    } else {
      _sendIntent('player_joined_intent', {
        'id': id,
        'displayName': name,
        'isHost': isHost,
        'hp': 5,
        'hand': [],
      });
    }
  }

  void dealCards() {
    if (!isHost) return;
    final random = Random();
    final updatedPlayers = _state.players.map((player) {
      final List<Card> hand = List.generate(5, (_) => Card(
        value: random.nextInt(13) + 2,
        isRevealed: false,
        ownerId: player.id,
      ));
      return player.copyWith(hand: hand, hp: 5);
    }).toList();

    _state = _state.copyWith(
      phase: GamePhase.playing,
      players: updatedPlayers,
      currentTurn: updatedPlayers.first.id,
      activeCard: null,
      declaredValue: null,
      turnHistory: ['Game Started!'],
    );
    notifyListeners();
    _broadcastState();
  }

  void playCard(Card card, int declaredValue) {
    if (!isHost) {
      _sendIntent('play_card_intent', {
        'card': card.toJson(),
        'declaredValue': declaredValue,
      });
      return;
    }

    if (_state.phase != GamePhase.playing || _state.activeCard != null) return;
    if (_state.currentTurn != card.ownerId) return;

    final player = _state.players.firstWhere((p) => p.id == card.ownerId);
    final newHand = player.hand.where((c) => !(c.value == card.value && c.ownerId == card.ownerId)).toList();
    
    final updatedPlayers = _state.players.map((p) => 
      p.id == player.id ? p.copyWith(hand: newHand) : p
    ).toList();

    _state = _state.copyWith(
      players: updatedPlayers,
      activeCard: card.copyWith(isRevealed: false),
      declaredValue: declaredValue,
      turnHistory: [..._state.turnHistory, '${player.displayName} played a card.'],
    );

    _toggleTurnInternal();
  }

  void submitChallenge() {
    if (!isHost) {
      _sendIntent('challenge_intent', {});
      return;
    }
    if (_state.phase != GamePhase.playing || _state.activeCard == null) return;
    _state = _state.copyWith(phase: GamePhase.reveal);
    notifyListeners();
    _broadcastState();
    Future.delayed(const Duration(seconds: 3), () => _resolveReveal());
  }

  void submitBelieve() {
    if (!isHost) {
      _sendIntent('believe_intent', {});
      return;
    }
    if (_state.phase != GamePhase.playing || _state.activeCard == null) return;
    final challenger = _state.players.firstWhere((p) => p.id == _state.currentTurn);
    _state = _state.copyWith(
      activeCard: null,
      declaredValue: null,
      turnHistory: [..._state.turnHistory, '${challenger.displayName} believed.'],
    );
    notifyListeners();
    _broadcastState();
  }

  void _resolveReveal() {
    if (!isHost) return;
    final activeCard = _state.activeCard!;
    final declaredValue = _state.declaredValue!;
    final isBluff = activeCard.value != declaredValue;
    
    final playerWhoPlayedId = activeCard.ownerId;
    final challengerId = _state.currentTurn!;

    final victimId = isBluff ? playerWhoPlayedId : challengerId;
    final winnerId = isBluff ? challengerId : playerWhoPlayedId;

    final victimName = _state.players.firstWhere((p) => p.id == victimId).displayName;
    final historyEntry = isBluff ? 'BLUFF! $victimName takes 1 DMG.' : 'TRUTH! $victimName takes 1 DMG.';

    _state = _state.copyWith(turnHistory: [..._state.turnHistory, historyEntry]);
    _applyDamage(victimId, winnerId);
  }

  void _applyDamage(String victimId, String winnerId) {
    final players = _state.players.map((p) => p.id == victimId ? p.copyWith(hp: p.hp - 1) : p).toList();
    bool matchEnded = players.any((p) => p.hp <= 0);
    
    _state = _state.copyWith(
      players: players,
      phase: matchEnded ? GamePhase.ended : GamePhase.roundEnd,
      activeCard: _state.activeCard?.copyWith(isRevealed: true), // Show actual value
    );
    notifyListeners();
    _broadcastState();

    if (!matchEnded) {
      Future.delayed(const Duration(seconds: 2), () {
        _drawCards();
        _state = _state.copyWith(
          phase: GamePhase.playing,
          currentTurn: winnerId,
          activeCard: null,
          declaredValue: null,
        );
        notifyListeners();
        _broadcastState();
      });
    }
  }

  void _drawCards() {
    final random = Random();
    final updatedPlayers = _state.players.map((p) {
      if (p.hand.length < 5) {
        final needed = 5 - p.hand.length;
        final newCards = List.generate(needed, (_) => Card(
          value: random.nextInt(13) + 2,
          isRevealed: false,
          ownerId: p.id,
        ));
        return p.copyWith(hand: [...p.hand, ...newCards]);
      }
      return p;
    }).toList();
    _state = _state.copyWith(players: updatedPlayers);
  }

  void _toggleTurnInternal() {
    final currentIndex = _state.players.indexWhere((p) => p.id == _state.currentTurn);
    final nextIndex = (currentIndex + 1) % _state.players.length;
    _state = _state.copyWith(currentTurn: _state.players[nextIndex].id);
    notifyListeners();
    _broadcastState();
  }

  void _addPlayerLocally(Player player) {
    if (!_state.players.any((p) => p.id == player.id)) {
      _state = _state.copyWith(players: [..._state.players, player]);
      notifyListeners();
    }
  }

  void _broadcastState() {
    if (!_network.isConnected) return;
    _sendGamePacket('state_sync', _state.toJson());
  }

  void _sendIntent(String type, Map<String, dynamic> data) {
    if (!_network.isConnected) return;
    _sendGamePacket(type, data);
  }

  void _sendGamePacket(String type, Map<String, dynamic> data) {
    _network.sendPacket({
      'version': 1,
      'type': type,
      'id': _generateUuid(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
  }

  String _generateUuid() {
    final random = Random();
    const chars = 'abcdef0123456789';
    return List.generate(32, (i) => chars[random.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _incomingPacketSubscription.cancel();
    _network.dispose();
    super.dispose();
  }
}
