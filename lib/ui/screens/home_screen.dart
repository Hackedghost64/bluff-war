import 'package:flutter/material.dart';
import '../../core/controllers/game_controller.dart';
import '../../core/models/game_state.dart';

class HomeScreen extends StatelessWidget {
  final GameController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'BLUFF P2P',
              style: TextStyle(
                color: Colors.white,
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
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
                // Discovery starts in the background via GuestManager
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
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueGrey[900],
          side: const BorderSide(color: Colors.blueAccent, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
        ),
      ),
    );
  }
}
