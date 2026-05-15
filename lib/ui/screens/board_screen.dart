import 'dart:math';
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
        
        final localPlayer = state.players.cast<Player?>().firstWhere(
          (p) => p?.id == controller.localPlayerId,
          orElse: () => null,
        );

        final opponent = state.players.cast<Player?>().firstWhere(
          (p) => p?.id != controller.localPlayerId,
          orElse: () => null,
        );

        if (localPlayer == null || opponent == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.blueAccent),
                  SizedBox(height: 20),
                  Text(
                    'WAITING FOR OPPONENT...',
                    style: TextStyle(color: Colors.white, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          );
        }

        final isMyTurn = state.currentTurn == controller.localPlayerId;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Column(
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
                      onPlayCard: (card) => _showDeclareDialog(context, card, controller),
                    ),
                  ],
                ),
                _PhaseOverlay(phase: state.phase),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeclareDialog(BuildContext context, model.Card card, GameController controller) {
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

class _HpDisplay extends StatefulWidget {
  final int hp;
  final Color baseColor;

  const _HpDisplay({required this.hp, required this.baseColor});

  @override
  State<_HpDisplay> createState() => _HpDisplayState();
}

class _HpDisplayState extends State<_HpDisplay> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut)
    );
  }

  @override
  void didUpdateWidget(covariant _HpDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hp < oldWidget.hp) {
      _shakeController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        // Simple sine wave shake dampening over time
        final offset = sin(_shakeAnimation.value * 4 * pi) * 8 * (1 - _shakeAnimation.value);
        final isAnimating = _shakeController.isAnimating;
        
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Text(
            'HP: ${widget.hp}',
            style: TextStyle(
              color: isAnimating ? Colors.white : widget.baseColor,
              fontWeight: FontWeight.bold,
              fontSize: isAnimating ? 22 : 18,
            ),
          ),
        );
      },
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
      color: Colors.red[900]?.withValues(alpha: 0.2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(player.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              _HpDisplay(hp: player.hp, baseColor: Colors.red),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(player.hand.length, (_) => const _CardWidget(isFaceDown: true)),
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
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), letterSpacing: 2),
        ),
      );
    }

    final bool showActions = isMyTurn && phase == GamePhase.playing;
    final bool isFaceDown = phase != GamePhase.reveal && phase != GamePhase.roundEnd && phase != GamePhase.ended;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          transitionBuilder: (Widget child, Animation<double> animation) {
            final rotate = Tween(begin: pi / 2, end: 0.0).animate(animation);
            return AnimatedBuilder(
              animation: rotate,
              child: child,
              builder: (context, child) {
                final isOutgoing = child!.key != ValueKey(isFaceDown);
                final angle = isOutgoing ? rotate.value : -rotate.value;
                return Transform(
                  transform: Matrix4.rotationY(angle)..setEntry(3, 2, 0.002),
                  alignment: Alignment.center,
                  child: child,
                );
              },
            );
          },
          child: _CardWidget(
            key: ValueKey(isFaceDown),
            value: activeCard!.value,
            isFaceDown: isFaceDown,
            sizeMultiplier: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'DECLARED: $declaredValue',
          style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: showActions ? 1.0 : 0.0,
            child: showActions
                ? Row(
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
                  )
                : const SizedBox.shrink(),
          ),
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
      color: Colors.blue[900]?.withValues(alpha: 0.2),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('YOU (${player.displayName})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              _HpDisplay(hp: player.hp, baseColor: Colors.blue),
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
  final double sizeMultiplier;

  const _CardWidget({super.key, this.value, this.isFaceDown = false, this.sizeMultiplier = 1.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60 * sizeMultiplier,
      height: 90 * sizeMultiplier,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isFaceDown ? Colors.blueGrey[800] : Colors.white,
        borderRadius: BorderRadius.circular(8 * sizeMultiplier),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(2, 2)),
        ],
      ),
      child: isFaceDown
          ? Center(child: Icon(Icons.help_outline, color: Colors.white24, size: 24 * sizeMultiplier))
          : Center(
              child: Text(
                value.toString(),
                style: TextStyle(color: Colors.black, fontSize: 24 * sizeMultiplier, fontWeight: FontWeight.bold),
              ),
            ),
    );
  }
}

class _PhaseOverlay extends StatelessWidget {
  final GamePhase phase;
  const _PhaseOverlay({required this.phase});

  @override
  Widget build(BuildContext context) {
    bool show = phase == GamePhase.reveal || phase == GamePhase.roundEnd;
    String text = '';
    if (phase == GamePhase.reveal) text = 'REVEALING...';
    if (phase == GamePhase.roundEnd) text = 'ROUND OVER';

    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)),
        child: show
            ? Container(
                key: ValueKey(phase),
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey[900],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blueAccent, width: 2),
                      boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
                    ),
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('none')),
      ),
    );
  }
}
