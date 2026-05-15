import 'card.dart';

class Player {
  final String id;
  final String displayName;
  final int hp;
  final List<Card> hand;
  final bool isHost;

  const Player({
    required this.id,
    required this.displayName,
    this.hp = 5,
    this.hand = const [],
    this.isHost = false,
  });

  Player copyWith({
    String? id,
    String? displayName,
    int? hp,
    List<Card>? hand,
    bool? isHost,
  }) {
    return Player(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      hp: hp ?? this.hp,
      hand: hand ?? this.hand,
      isHost: isHost ?? this.isHost,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'hp': hp,
      'hand': hand.map((c) => c.toJson()).toList(),
      'isHost': isHost,
    };
  }

  factory Player.fromJson(Map<String, dynamic> json) {
    return Player(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      hp: json['hp'] as int,
      hand: (json['hand'] as List<dynamic>)
          .map((c) => Card.fromJson(c as Map<String, dynamic>))
          .toList(),
      isHost: json['isHost'] as bool,
    );
  }
}
