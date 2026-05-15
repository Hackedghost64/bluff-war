class Card {
  final int value;
  final bool isRevealed;
  final String ownerId;

  const Card({
    required this.value,
    required this.isRevealed,
    required this.ownerId,
  });

  Card copyWith({
    int? value,
    bool? isRevealed,
    String? ownerId,
  }) {
    return Card(
      value: value ?? this.value,
      isRevealed: isRevealed ?? this.isRevealed,
      ownerId: ownerId ?? this.ownerId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'isRevealed': isRevealed,
      'ownerId': ownerId,
    };
  }

  factory Card.fromJson(Map<String, dynamic> json) {
    return Card(
      value: json['value'] as int,
      isRevealed: json['isRevealed'] as bool,
      ownerId: json['ownerId'] as String,
    );
  }
}
