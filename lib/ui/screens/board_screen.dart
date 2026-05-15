import 'package:flutter/material.dart';
import '../../core/controllers/game_controller.dart';
import '../../core/models/game_state.dart';
import '../../core/models/player.dart';
import '../../core/models/card.dart' as model;

class BoardScreen extends StatelessWidget {
  final GameController controller;

  const BoardScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final localPlayer = state.players.firstWhere((p) => p.id == controller.localPlayerId);
        final opponent = state.players.firstWhere((p) => p.id != controller.localPlayerId);
        final isMyTurn = state.currentTurn == controller.localPlayerId;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                // Top Section: Opponent
                _OpponentSection(player: opponent),
                
                // Center Section: Field
                Expanded(
                  child: _FieldSection(
                    activeCard: state.activeCard,
                    declaredValue: state.declaredValue,
                    phase: state.phase,
                    isMyTurn: isMyTurn,
                    onBelieve: () => controller.submitBelieve(),
                    onChallenge: () => controller.submitChallenge(),
                  ),
                ),
                
                // Bottom Section: Player
                _PlayerSection(
                  player: localPlayer,
                  isMyTurn: isMyTurn && state.activeCard == null && state.phase == GamePhase.playing,
                  onPlayCard: (card) => _showDeclareDialog(context, card),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeclareDialog(BuildContext context, model.Card card) {
    int selectedValue = card.value;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.blueGrey[900],
        title: const Text('DECLARE VALUE', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Actual: ${card.value}', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              DropdownButton<int>(
                value: selectedValue,
                dropdownColor: Colors.blueGrey[800],
                items: List.generate(13, (i) => i + 2)
                    .map((v) => DropdownMenuItem(
                          value: v,
                          child: Text(v.toString(), style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => selectedValue = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () {
              controller.playCard(card, selectedValue);
              Navigator.pop(context);
            },
            child: const Text('PLAY'),
          ),
        ],
      ),
    );
  }
}

class _OpponentSection extends StatelessWidget {
  final Player player;
  const _OpponentSection({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.red[900]?.withOpacity(0.2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(player.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('HP: ${player.hp}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(player.hand.length, (_) => _CardWidget(isFaceDown: true)),
          ),
        ],
      ),
    );
  }
}

class _FieldSection extends StatelessWidget {
  final model.Card? activeCard;
  final int? declaredValue;
  final GamePhase phase;
  final bool isMyTurn;
  final VoidCallback onBelieve;
  final VoidCallback onChallenge;

  const _FieldSection({
    required this.activeCard,
    required this.declaredValue,
    required this.phase,
    required this.isMyTurn,
    required this.onBelieve,
    required this.onChallenge,
  });

  @override
  Widget build(BuildContext context) {
    if (activeCard == null) {
      return Center(
        child: Text(
          isMyTurn ? "YOUR TURN - PLAY A CARD" : "WAITING FOR OPPONENT...",
          style: TextStyle(color: Colors.white.withOpacity(0.5), letterSpacing: 2),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CardWidget(
          value: activeCard!.value,
          isFaceDown: phase != GamePhase.reveal,
        ),
        const SizedBox(height: 10),
        Text(
          'DECLARED: $declaredValue',
          style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        if (isMyTurn && phase == GamePhase.playing) ...[
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: onBelieve,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green[800]),
                child: const Text('BELIEVE'),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                onPressed: onChallenge,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red[800]),
                child: const Text('CHALLENGE'),
              ),
            ],
          ),
        ],
        if (phase == GamePhase.reveal)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Text('REVEALING...', style: TextStyle(color: Colors.blueAccent, fontSize: 20)),
          ),
      ],
    );
  }
}

class _PlayerSection extends StatelessWidget {
  final Player player;
  final bool isMyTurn;
  final Function(model.Card) onPlayCard;

  const _PlayerSection({
    required this.player,
    required this.isMyTurn,
    required this.onPlayCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[900]?.withOpacity(0.2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('YOU (${player.displayName})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('HP: ${player.hp}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: player.hand
                  .map((card) => GestureDetector(
                        onTap: isMyTurn ? () => onPlayCard(card) : null,
                        child: _CardWidget(value: card.value),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardWidget extends StatelessWidget {
  final int? value;
  final bool isFaceDown;

  const _CardWidget({this.value, this.isFaceDown = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 90,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isFaceDown ? Colors.blueGrey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4, offset: const Offset(2, 2)),
        ],
      ),
      child: isFaceDown
          ? const Center(child: Icon(Icons.help_outline, color: Colors.white24))
          : Center(
              child: Text(
                value.toString(),
                style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}
