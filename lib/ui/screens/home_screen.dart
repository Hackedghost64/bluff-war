import 'package:flutter/material.dart';
import '../../core/controllers/game_controller.dart';
import '../widgets/canvas_app_icon.dart';

class HomeScreen extends StatelessWidget {
  final GameController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHost = controller.isHost;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CanvasAppIcon(size: 80),
            const SizedBox(height: 40),
            Text(
              isHost ? 'CREATING LOBBY...' : 'SEARCHING FOR HOST...',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white70,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 60),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber),
            ),
            const SizedBox(height: 40),
            Text(
              isHost 
                ? 'Setting up local server...' 
                : 'Please ensure Bluetooth is enabled and the host is nearby.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
