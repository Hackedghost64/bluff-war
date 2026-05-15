import 'package:flutter/material.dart';
import '../../core/controllers/game_controller.dart';
import '../../core/models/game_state.dart';
import '../widgets/canvas_app_icon.dart';

class HomeScreen extends StatelessWidget {
  final GameController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CanvasAppIcon(size: 100),
            const SizedBox(height: 40),
            Text('BLUFF P2P', style: theme.textTheme.displayLarge),
            const SizedBox(height: 60),
            _MenuButton(
              label: 'HOST GAME',
              onPressed: () {
                controller.addPlayer('host_1', 'Player 1', isHost: true);
                controller.setPhase(GamePhase.lobby);
              },
            ),
            const SizedBox(height: 20),
            _MenuButton(
              label: 'JOIN GAME',
              onPressed: () {
                controller.setPhase(GamePhase.lobby);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _MenuButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}
