import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'core/controllers/game_controller.dart';
import 'core/models/game_state.dart';
import 'core/network/guest_manager.dart';
import 'core/network/host_manager.dart';
import 'core/network/network_manager.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/screens/board_screen.dart';
import 'ui/debug/state_inspector.dart';
import 'ui/debug/network_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  const String envRole = String.fromEnvironment('role');
  String role = envRole.isNotEmpty ? envRole.toLowerCase() : (Platform.isLinux ? 'guest' : 'host');

  runApp(BluffApp(initialRole: role));
}

class BluffApp extends StatefulWidget {
  final String initialRole;
  const BluffApp({super.key, required this.initialRole});

  @override
  State<BluffApp> createState() => _BluffAppState();
}

class _BluffAppState extends State<BluffApp> {
  late GameController _controller;
  late NetworkManager _network;

  @override
  void initState() {
    super.initState();
    _network = widget.initialRole == 'host' ? HostManager() : GuestManager();
    _controller = GameController(_network);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final phase = _controller.state.phase;
        
        Widget screen;
        switch (phase) {
          case GamePhase.initial:
            screen = HomeScreen(controller: _controller);
            break;
          case GamePhase.lobby:
            screen = LobbyScreen(controller: _controller);
            break;
          case GamePhase.playing:
          case GamePhase.reveal:
          case GamePhase.roundEnd:
            screen = BoardScreen(controller: _controller);
            break;
          default:
            screen = HomeScreen(controller: _controller);
        }

        return MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                screen,
                if (kDebugMode) ...[
                  const NetworkOverlay(),
                  StateInspector(controller: _controller),
                ],
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
          theme: ThemeData.dark(),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
