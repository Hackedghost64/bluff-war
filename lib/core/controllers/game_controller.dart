import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/game_state.dart';
import '../models/player.dart';
import '../models/card.dart';
import '../network/network_manager.dart';
import '../utils/net_logger.dart';

class GameController extends ChangeNotifier {
  final NetworkManager _network;
  GameState _state = const GameState();
  String? _localPlayerId;

  GameController(this._network) {
    _network.incomingPackets.listen(_handleIncomingPacket);
  }

  GameState get state => _state;
  String? get localPlayerId => _localPlayerId;

  void setLocalPlayerId(String id) {
    _localPlayerId = id;
    notifyListeners();
  }

  void _handleIncomingPacket(Map<String, dynamic> packet) {
    try {
      final type = packet['type'] as String;
      final data = packet['data'] as Map<String, dynamic>;

      switch (type) {
        case 'state_sync':
          final newState = GameState.fromJson(data);
          if (_isValidTransition(_state.phase, newState.phase)) {
            _state = newState;
            notifyListeners();
          } else {
            NetLogger.error('CRITICAL: Illegal phase transition received via network: ${_state.phase} -> ${newState.phase}');
          }
          break;
        case 'player_joined':
          final newPlayer = Player.fromJson(data);
          _addPlayerLocally(newPlayer);
          break;
      }
    } catch (e) {
      NetLogger.error('Controller failed to handle packet', e);
    }
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
      default:
        return false;
    }
  }

  // --- UI Intents ---

  void setPhase(GamePhase phase) {
    if (!_isValidTransition(_state.phase, phase)) {
      NetLogger.error('ILLEGAL UI TRANSITION: ${_state.phase} -> $phase');
      assert(false, 'Illegal phase transition: ${_state.phase} -> $phase');
      return;
    }
    
    _state = _state.copyWith(phase: phase);
    notifyListeners();
    _broadcastState();
  }

  void addPlayer(String id, String name, {bool isHost = false}) {
    if (_localPlayerId == null) _localPlayerId = id;
    final player = Player(id: id, displayName: name, isHost: isHost);
    _addPlayerLocally(player);
    _broadcastState();
  }

  void dealCards() {
    if (!_isValidTransition(_state.phase, GamePhase.playing)) return;
    
    NetLogger.log('Logic -> Dealing cards...');
    final random = Random();
    final List<Player> updatedPlayers = [];
    
    for (var player in _state.players) {
      final List<Card> hand = List.generate(5, (_) => Card(
        value: random.nextInt(13) + 2, // 2-14
        isRevealed: false,
        ownerId: player.id,
      ));
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
    assert(_state.phase == GamePhase.playing);
    assert(_state.currentTurn == _localPlayerId);
    assert(_state.activeCard == null);

    final player = _state.players.firstWhere((p) => p.id == _localPlayerId);
    final newHand = player.hand.where((c) => c != card).toList();
    final updatedPlayers = _state.players.map((p) => p.id == player.id ? p.copyWith(hand: newHand) : p).toList();

    _state = _state.copyWith(
      players: updatedPlayers,
      activeCard: card.copyWith(isRevealed: false),
      declaredValue: declaredValue,
    );

    toggleTurn();
  }

  void submitChallenge() {
    assert(_state.phase == GamePhase.playing);
    assert(_state.currentTurn == _localPlayerId);
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
    assert(_state.phase == GamePhase.playing);
    assert(_state.currentTurn == _localPlayerId);
    assert(_state.activeCard != null);

    NetLogger.log('Logic -> Player believed the bluff.');
    _state = _state.copyWith(
      activeCard: null,
      declaredValue: null,
    );
    
    toggleTurn();
  }

  void _resolveReveal() {
    final activeCard = _state.activeCard!;
    final declaredValue = _state.declaredValue!;
    final isBluff = activeCard.value != declaredValue;

    NetLogger.log('Logic -> Resolving reveal. Card: ${activeCard.value}, Declared: $declaredValue. Bluff: $isBluff');

    final challengerId = _localPlayerId!;
    final playerWhoPlayedId = _state.players.firstWhere((p) => p.id != challengerId).id;

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

  void toggleTurn() {
    final nextPlayer = _state.players.firstWhere((p) => p.id != _state.currentTurn).id;
    _state = _state.copyWith(currentTurn: nextPlayer);
    
    notifyListeners();
    _broadcastState();
  }

  // --- Internal ---

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
