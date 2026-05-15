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

  // Task 4: O(1) Deduplication Queue
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

  void _handleIncomingPacket(Map<String, dynamic> packet) {
    try {
      // Task 3: Strict Schema Validation
      if (!_isValidSchema(packet)) {
        NetLogger.warning('Rejected packet with invalid schema: $packet');
        return;
      }

      final String packetId = packet['id'] as String;

      // Task 4: O(1) Deduplication Queue
      if (_processedPacketIds.contains(packetId)) {
        NetLogger.info('Discarding duplicate packet: $packetId');
        return;
      }

      _markPacketAsProcessed(packetId);

      final type = packet['type'] as String;
      final data = packet['data'] as Map<String, dynamic>;

      // SYSTEM EVENT — handled regardless of role
      if (type == 'system_disconnect') {
        _handleSystemDisconnect();
        return;
      }

      // Task 1: Host-Authoritative State Machine Routing
      if (isHost) {
        _handleHostIntents(type, data);
      } else {
        _handleGuestUpdates(type, data);
      }
    } catch (e) {
      NetLogger.error('Controller failed to handle packet', e);
    }
  }

  Timer? _reconnectTimer;

  void _handleSystemDisconnect() {
    _reconnectTimer?.cancel();
    if (_disconnectGracePeriod == Duration.zero) {
      NetLogger.critical(
        'Hardware disconnect detected. Resetting session immediately.',
      );
      _resetStateToInitial();
      return;
    }

    NetLogger.critical(
      'Hardware disconnect detected. Initiating ${_disconnectGracePeriod.inSeconds}-second session restore window...',
    );
    _reconnectTimer = Timer(_disconnectGracePeriod, () {
      NetLogger.critical('Session restore window expired. Brutal reset.');
      _resetStateToInitial();
    });
  }

  void _resetStateToInitial() {
    if (_state.phase == GamePhase.initial) {
      return;
    }

    _state = GameState.initial();
    notifyListeners();
  }

  void _handleHostIntents(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'play_card_intent':
        final card = Card.fromJson(data['card'] as Map<String, dynamic>);
        final declaredValue = data['declaredValue'] as int;
        final senderId = data['senderId'] as String;
        if (_state.currentTurn == senderId) {
          playCard(card, declaredValue);
        }
        break;
      case 'challenge_intent':
        final senderId = data['senderId'] as String;
        if (_state.currentTurn == senderId) {
          submitChallenge();
        }
        break;
      case 'believe_intent':
        final senderId = data['senderId'] as String;
        if (_state.currentTurn == senderId) {
          submitBelieve();
        }
        break;
      case 'player_joined_intent':
        final newPlayer = Player.fromJson(data);
        _addPlayerLocally(newPlayer);
        _broadcastState();
        break;
    }
  }

  void _handleGuestUpdates(String type, Map<String, dynamic> data) {
    switch (type) {
      case 'state_sync':
        final newState = GameState.fromJson(data);
        if (_isValidTransition(_state.phase, newState.phase)) {
          _state = newState;
          notifyListeners();
        } else {
          NetLogger.error(
            'CRITICAL: Illegal phase transition received via network: ${_state.phase} -> ${newState.phase}',
          );
        }
        break;
    }
  }

  bool _isValidSchema(Map<String, dynamic> packet) {
    return packet.containsKey('version') &&
        packet['version'] == 1 &&
        packet.containsKey('type') &&
        packet['type'] is String &&
        packet.containsKey('id') &&
        packet['id'] is String &&
        packet.containsKey('timestamp') &&
        packet['timestamp'] is int &&
        packet.containsKey('data') &&
        packet['data'] is Map<String, dynamic>;
  }

  void _markPacketAsProcessed(String id) {
    if (_processedPacketIds.length >= 100) {
      final oldestId = _packetIdHistory.removeAt(0);
      _processedPacketIds.remove(oldestId);
    }
    _processedPacketIds.add(id);
    _packetIdHistory.add(id);
  }

  // --- State Machine Validation ---

  bool _isValidTransition(GamePhase current, GamePhase next) {
    if (current == next) return true;
    switch (current) {
      case GamePhase.initial:
        return next == GamePhase.lobby;
      case GamePhase.lobby:
        return next == GamePhase.dealing;
      case GamePhase.dealing:
        return next == GamePhase.playing;
      case GamePhase.playing:
        return next == GamePhase.reveal;
      case GamePhase.reveal:
        return next == GamePhase.roundEnd || next == GamePhase.ended;
      case GamePhase.roundEnd:
        return next == GamePhase.playing || next == GamePhase.ended;
      case GamePhase.ended:
        return next == GamePhase.lobby;
    }
  }

  // --- UI Intents ---

  void setPhase(GamePhase phase) {
    if (!isHost) {
      return;
    }

    if (!_isValidTransition(_state.phase, phase)) {
      NetLogger.error('ILLEGAL UI TRANSITION: ${_state.phase} -> $phase');
      assert(false, 'Illegal phase transition: ${_state.phase} -> $phase');
      return;
    }

    NetLogger.transition(
      'PHASE TRANSITION: ${_state.phase.name} -> ${phase.name}',
    );
    _state = _state.copyWith(phase: phase);
    notifyListeners();
    _broadcastState();
  }

  void addPlayer(String id, String name, {bool isHost = false}) {
    _localPlayerId ??= id;
    if (this.isHost) {
      final player = Player(id: id, displayName: name, isHost: isHost);
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
    if (_state.phase != GamePhase.dealing) {
      NetLogger.error(
        'Logic -> Cannot deal cards outside dealing phase. Current: ${_state.phase}',
      );
      return;
    }

    NetLogger.log('Logic -> Dealing cards...');
    final random = Random();
    final List<Player> updatedPlayers = [];

    for (var player in _state.players) {
      final List<Card> hand = List.generate(
        5,
        (_) => Card(
          value: random.nextInt(13) + 2, // 2-14
          isRevealed: false,
          ownerId: player.id,
        ),
      );
      updatedPlayers.add(player.copyWith(hand: hand, hp: 5));
    }

    _state = _state.copyWith(
      phase: GamePhase.playing,
      players: updatedPlayers,
      currentTurn: _state.players.first.id,
      activeCard: null,
      declaredValue: null,
    );

    notifyListeners();
    _broadcastState();
  }

  void playCard(Card card, int declaredValue) {
    if (!isHost) {
      _sendIntent('play_card_intent', {
        'card': card.toJson(),
        'declaredValue': declaredValue,
        'senderId': _localPlayerId,
      });
      return;
    }

    assert(_state.phase == GamePhase.playing);
    assert(_state.activeCard == null);

    final player = _state.players.firstWhere((p) => p.id == _state.currentTurn);
    final newHand = player.hand
        .where((c) => c.value != card.value || c.ownerId != card.ownerId)
        .toList();
    final updatedPlayers = _state.players
        .map((p) => p.id == player.id ? p.copyWith(hand: newHand) : p)
        .toList();

    _state = _state.copyWith(
      players: updatedPlayers,
      activeCard: card.copyWith(isRevealed: false),
      declaredValue: declaredValue,
    );

    toggleTurn();
  }

  void submitChallenge() {
    if (!isHost) {
      _sendIntent('challenge_intent', {'senderId': _localPlayerId});
      return;
    }

    assert(_state.phase == GamePhase.playing);
    assert(_state.activeCard != null);

    if (!_isValidTransition(_state.phase, GamePhase.reveal)) return;

    _state = _state.copyWith(phase: GamePhase.reveal);
    notifyListeners();
    _broadcastState();

    Future.delayed(const Duration(seconds: 2), () {
      _resolveReveal();
    });
  }

  void submitBelieve() {
    if (!isHost) {
      _sendIntent('believe_intent', {'senderId': _localPlayerId});
      return;
    }

    assert(_state.phase == GamePhase.playing);
    assert(_state.activeCard != null);

    NetLogger.log('Logic -> Player believed the bluff.');
    final player = _state.players.firstWhere((p) => p.id == _state.currentTurn);

    AudioService.playTurnTick();

    _state = _state.copyWith(
      activeCard: null,
      declaredValue: null,
      turnHistory: [..._state.turnHistory, '${player.displayName} believed.'],
    );

    toggleTurn();
  }

  void _resolveReveal() {
    final activeCard = _state.activeCard!;
    final declaredValue = _state.declaredValue!;
    final isBluff = activeCard.value != declaredValue;

    NetLogger.log(
      'Logic -> Resolving reveal. Card: ${activeCard.value}, Declared: $declaredValue. Bluff: $isBluff',
    );

    final playerWhoPlayedId = activeCard.ownerId;
    final challengerId = _state.players
        .firstWhere((p) => p.id != playerWhoPlayedId)
        .id;

    if (isBluff) {
      _applyDamage(playerWhoPlayedId);
    } else {
      _applyDamage(challengerId);
    }
  }

  void _applyDamage(String playerId) {
    final players = _state.players.map((p) {
      if (p.id == playerId) {
        final newHp = p.hp - 1;
        return p.copyWith(hp: newHp);
      }
      return p;
    }).toList();

    bool matchEnded = players.any((p) => p.hp <= 0);
    final nextPhase = matchEnded ? GamePhase.ended : GamePhase.roundEnd;

    if (!_isValidTransition(_state.phase, nextPhase)) return;

    _state = _state.copyWith(
      players: players,
      phase: nextPhase,
      activeCard: null,
      declaredValue: null,
    );
    notifyListeners();
    _broadcastState();

    if (!matchEnded) {
      Future.delayed(const Duration(seconds: 2), () {
        if (!_isValidTransition(_state.phase, GamePhase.playing)) return;
        _drawCards();
        _state = _state.copyWith(phase: GamePhase.playing);
        toggleTurn();
      });
    }
  }

  void _drawCards() {
    final random = Random();
    final updatedPlayers = _state.players.map((p) {
      if (p.hand.length < 5) {
        final needed = 5 - p.hand.length;
        final newCards = List.generate(
          needed,
          (_) => Card(
            value: random.nextInt(13) + 2,
            isRevealed: false,
            ownerId: p.id,
          ),
        );
        return p.copyWith(hand: [...p.hand, ...newCards]);
      }
      return p;
    }).toList();
    _state = _state.copyWith(players: updatedPlayers);
  }

  void toggleTurn() {
    final nextPlayer = _state.players
        .firstWhere((p) => p.id != _state.currentTurn)
        .id;
    _state = _state.copyWith(currentTurn: nextPlayer);

    notifyListeners();
    _broadcastState();
  }

  // --- Internal ---

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
    unawaited(_incomingPacketSubscription.cancel());
    unawaited(_network.dispose());
    super.dispose();
  }
}
