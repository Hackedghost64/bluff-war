import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/controllers/game_controller.dart';
import '../../core/models/game_state.dart';
import '../../core/models/player.dart';
import '../../core/models/card.dart' as model;
import '../../core/services/haptic_service.dart';

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

        final List<Player> otherPlayers = state.players
            .where((p) => p.id != controller.localPlayerId)
            .toList();

        if (localPlayer == null) {
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isMyTurn = state.currentTurn == controller.localPlayerId;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                _ShakeEffect(
                  trigger: state.phase == GamePhase.reveal,
                  child: Column(
                    children: [
                      // Opponents Section
                      _OpponentsRow(players: otherPlayers, currentTurn: state.currentTurn),
                      
                      const Divider(color: Colors.white24, height: 1),

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
                      
                      // History Timeline
                      _HistoryTimeline(history: state.turnHistory),

                      // Player Section
                      _PlayerSection(
                        player: localPlayer,
                        isMyTurn: isMyTurn && state.activeCard == null && state.phase == GamePhase.playing,
                        onPlayCard: (card) {
                          HapticService.light();
                          _showDeclareDialog(context, card, controller);
                        },
                      ),
                    ],
                  ),
                ),
                if (state.phase == GamePhase.reveal)
                  IgnorePointer(
                    child: Container(
                      color: Colors.red.withOpacity(0.1),
                    ),
                  ),
                if (state.phase == GamePhase.ended)
                  _GameOverOverlay(
                    players: state.players,
                    onReset: () => controller.resetGame(),
                    isHost: controller.isHost,
                  ),
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
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

class _OpponentsRow extends StatelessWidget {
  final List<Player> players;
  final String? currentTurn;
  const _OpponentsRow({required this.players, required this.currentTurn});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: players.map((p) => _OpponentAvatar(player: p, isTurn: p.id == currentTurn)).toList(),
      ),
    );
  }
}

class _OpponentAvatar extends StatelessWidget {
  final Player player;
  final bool isTurn;
  const _OpponentAvatar({required this.player, required this.isTurn});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isTurn)
          const _PulseEffect(
            child: CircleAvatar(
              backgroundColor: Colors.amber,
              radius: 22,
              child: CircleAvatar(
                backgroundColor: Colors.red,
                radius: 20,
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.transparent, width: 2),
            ),
            child: CircleAvatar(
              backgroundColor: Colors.red[900],
              radius: 20,
              child: Text(player.displayName[0], style: const TextStyle(color: Colors.white)),
            ),
          ),
        const SizedBox(height: 4),
        Text(player.displayName, style: const TextStyle(color: Colors.white, fontSize: 10)),
        Text('HP: ${player.hp}', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
        Row(
          children: List.generate(player.hand.length, (_) => Container(
            width: 4, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1), color: Colors.blueGrey,
          )),
        ),
      ],
    );
  }
}

class _PulseEffect extends StatefulWidget {
  final Widget child;
  const _PulseEffect({required this.child});

  @override
  State<_PulseEffect> createState() => _PulseEffectState();
}

class _PulseEffectState extends State<_PulseEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: widget.child);
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
          isMyTurn ? "YOUR TURN\nPLAY A CARD" : "WAITING...",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withOpacity(0.3), letterSpacing: 2, fontSize: 24),
        ),
      );
    }

    final bool showActions = isMyTurn && phase == GamePhase.playing;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (phase == GamePhase.reveal || phase == GamePhase.roundEnd)
          _DramaticRevealCard(value: activeCard!.value, isRevealed: activeCard!.isRevealed)
        else
          const _SlideInEffect(
            child: _CardWidget(isFaceDown: true, sizeMultiplier: 1.5),
          ),
        const SizedBox(height: 20),
        Text(
          'DECLARED: $declaredValue',
          style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        if (showActions)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(label: 'BELIEVE', color: Colors.green[800]!, onPressed: onBelieve),
              const SizedBox(width: 20),
              _ActionButton(label: 'CHALLENGE', color: Colors.red[800]!, onPressed: onChallenge),
            ],
          ),
      ],
    );
  }
}

class _SlideInEffect extends StatefulWidget {
  final Widget child;
  const _SlideInEffect({required this.child});

  @override
  State<_SlideInEffect> createState() => _SlideInEffectState();
}

class _SlideInEffectState extends State<_SlideInEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _offset = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _offset, child: widget.child);
  }
}

class _ShakeEffect extends StatefulWidget {
  final Widget child;
  final bool trigger;
  const _ShakeEffect({required this.child, required this.trigger});

  @override
  State<_ShakeEffect> createState() => _ShakeEffectState();
}

class _ShakeEffectState extends State<_ShakeEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 50));
    if (widget.trigger) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _ShakeEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger && !oldWidget.trigger) {
      _controller.repeat(reverse: true);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _controller.stop();
      });
    } else if (!widget.trigger && oldWidget.trigger) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final offset = widget.trigger ? (Random().nextDouble() * 10 - 5) : 0.0;
        return Transform.translate(
          offset: Offset(offset, offset),
          child: widget.child,
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;
  const _ActionButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      child: Text(label),
    );
  }
}

class _DramaticRevealCard extends StatefulWidget {
  final int value;
  final bool isRevealed;
  const _DramaticRevealCard({required this.value, required this.isRevealed});

  @override
  State<_DramaticRevealCard> createState() => _DramaticRevealCardState();
}

class _DramaticRevealCardState extends State<_DramaticRevealCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _flip;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _flip = Tween<double>(begin: pi, end: 0.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _DramaticRevealCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed && !oldWidget.isRevealed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isFaceDown = _flip.value > pi / 2;
        return Transform(
          transform: Matrix4.rotationY(_flip.value)..setEntry(3, 2, 0.002),
          alignment: Alignment.center,
          child: _CardWidget(
            value: widget.value,
            isFaceDown: isFaceDown,
            sizeMultiplier: 1.5,
          ),
        );
      },
    );
  }
}

class _HistoryTimeline extends StatelessWidget {
  final List<String> history;
  const _HistoryTimeline({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: double.infinity,
      color: Colors.black45,
      child: Center(
        child: Text(
          history.isEmpty ? "" : history.last,
          style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PlayerSection extends StatelessWidget {
  final Player player;
  final bool isMyTurn;
  final Function(model.Card) onPlayCard;

  const _PlayerSection({required this.player, required this.isMyTurn, required this.onPlayCard});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMyTurn ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        border: Border(top: BorderSide(color: isMyTurn ? Colors.blue : Colors.white10, width: 2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(player.displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              Text('HP: ${player.hp}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: player.hand.map((card) => GestureDetector(
                onTap: isMyTurn ? () => onPlayCard(card) : null,
                child: _CardWidget(value: card.value),
              )).toList(),
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

  const _CardWidget({this.value, this.isFaceDown = false, this.sizeMultiplier = 1.0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50 * sizeMultiplier,
      height: 75 * sizeMultiplier,
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isFaceDown ? Colors.blueGrey[800] : Colors.white,
        borderRadius: BorderRadius.circular(6 * sizeMultiplier),
        border: Border.all(color: Colors.white24),
      ),
      child: isFaceDown
          ? Center(child: Icon(Icons.help_outline, color: Colors.white24, size: 20 * sizeMultiplier))
          : Center(child: Text(value.toString(), style: TextStyle(color: Colors.black, fontSize: 20 * sizeMultiplier, fontWeight: FontWeight.bold))),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  final List<Player> players;
  final VoidCallback onReset;
  final bool isHost;

  const _GameOverOverlay({required this.players, required this.onReset, required this.isHost});

  @override
  Widget build(BuildContext context) {
    final winner = players.reduce((a, b) => a.hp > b.hp ? a : b);
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('GAME OVER', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 20),
            Text('${winner.displayName} WINS!', style: const TextStyle(color: Colors.amber, fontSize: 24)),
            const SizedBox(height: 40),
            if (isHost)
              ElevatedButton(onPressed: onReset, child: const Text('NEW GAME'))
            else
              const Text('Waiting for host to reset...', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
          ],
        ),
      ),
    );
  }
}
