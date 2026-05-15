import 'package:flutter/material.dart';
import '../../core/controllers/game_controller.dart';
import '../../core/models/game_state.dart';

class LobbyScreen extends StatelessWidget {
  final GameController controller;

  const LobbyScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final theme = Theme.of(context);
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('GAME LOBBY'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: state.players.length,
                    itemBuilder: (context, index) {
                      final player = state.players[index];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: player.isHost ? theme.colorScheme.error : theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            child: Text(player.displayName[0]),
                          ),
                          title: Text(
                            player.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          trailing: player.isHost
                              ? Icon(Icons.star, color: theme.colorScheme.secondary)
                              : Text('READY', style: TextStyle(color: theme.colorScheme.primary)),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (controller.isHost)
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        controller.setPhase(GamePhase.dealing);
                      },
                      child: const Text('START GAME'),
                    ),
                  ),
                if (!controller.isHost)
                  const Text('Waiting for Host to start...', style: TextStyle(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        );
      },
    );
  }
}
