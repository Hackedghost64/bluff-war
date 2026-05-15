import 'player.dart';
import 'card.dart';

enum GamePhase { initial, lobby, dealing, playing, reveal, roundEnd, ended }

class GameState {
  final GamePhase phase;
  final List<Player> players;
  final String? currentTurn;
  final Map<String, int> roundScores;
  final Card? activeCard;
  final int? declaredValue;

  const GameState({
    this.phase = GamePhase.initial,
    this.players = const [],
    this.currentTurn,
    this.roundScores = const {},
    this.activeCard,
    this.declaredValue,
  });

  factory GameState.initial() => const GameState();

  GameState copyWith({
    GamePhase? phase,
    List<Player>? players,
    String? currentTurn,
    Map<String, int>? roundScores,
    Card? activeCard,
    int? declaredValue,
  }) {
    return GameState(
      phase: phase ?? this.phase,
      players: players ?? this.players,
      currentTurn: currentTurn ?? this.currentTurn,
      roundScores: roundScores ?? this.roundScores,
      activeCard: activeCard ?? this.activeCard,
      declaredValue: declaredValue ?? this.declaredValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'phase': phase.name,
      'players': players.map((p) => p.toJson()).toList(),
      'currentTurn': currentTurn,
      'roundScores': roundScores,
      'activeCard': activeCard?.toJson(),
      'declaredValue': declaredValue,
    };
  }

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      phase: GamePhase.values.byName(json['phase'] as String),
      players: (json['players'] as List<dynamic>)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
      currentTurn: json['currentTurn'] as String?,
      roundScores: Map<String, int>.from(json['roundScores'] as Map),
      activeCard: json['activeCard'] != null
          ? Card.fromJson(json['activeCard'] as Map<String, dynamic>)
          : null,
      declaredValue: json['declaredValue'] as int?,
    );
  }
}
