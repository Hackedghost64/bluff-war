import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter/foundation.dart';
import 'dart:math';
import 'core/controllers/game_controller.dart';
import 'core/models/game_state.dart';
import 'core/network/guest_manager.dart';
import 'core/network/host_manager.dart';
import 'core/network/network_manager.dart';
import 'core/services/update_service.dart';
import 'ui/screens/home_screen.dart';
import 'ui/screens/lobby_screen.dart';
import 'ui/screens/board_screen.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/debug/state_inspector.dart';
import 'ui/debug/network_overlay.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/canvas_app_icon.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BluffApp());
}

class BluffApp extends StatefulWidget {
  const BluffApp({super.key});

  @override
  State<BluffApp> createState() => _BluffAppState();
}

class _BluffAppState extends State<BluffApp> {
  GameController? _controller;
  bool _showSplash = true;
  final TextEditingController _nameController = TextEditingController(text: 'Player ${Random().nextInt(100)}');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  void _initializeSession(bool isHost) async {
    final network = isHost ? HostManager() : GuestManager();
    await network.initialize();
    
    final controller = GameController(network);
    controller.setLocalPlayerName(_nameController.text);

    setState(() {
      _controller = controller;
    });

    if (isHost) {
      controller.addPlayer('host_1', _nameController.text, isHost: true);
      await (network as HostManager).startAdvertising();
      controller.setPhase(GamePhase.lobby);
    } else {
      await (network as GuestManager).startDiscovery();
    }
  }

  void _showHowToPlay(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'HTP',
      pageBuilder: (context, anim1, anim2) => const HowToPlayDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: SplashScreen(
          onComplete: () {
            setState(() {
              _showSplash = false;
            });
          },
        ),
      );
    }

    if (_controller == null) {
      return MaterialApp(
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Hero(tag: 'app_icon', child: CanvasAppIcon(size: 80)),
                  const SizedBox(height: 20),
                  Text('BLUFF P2P', style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 40),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'YOUR NAME',
                        border: OutlineInputBorder(),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _EntryButton(label: 'HOST GAME', onPressed: () => _initializeSession(true)),
                  const SizedBox(height: 20),
                  _EntryButton(label: 'JOIN GAME', onPressed: () => _initializeSession(false)),
                  const SizedBox(height: 40),
                  TextButton.icon(
                    onPressed: () => _showHowToPlay(context),
                    icon: const Icon(Icons.help_outline),
                    label: const Text('HOW TO PLAY'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: _controller!,
      builder: (context, _) {
        final phase = _controller!.state.phase;
        
        Widget screen;
        switch (phase) {
          case GamePhase.initial:
            screen = HomeScreen(controller: _controller!);
            break;
          case GamePhase.lobby:
            screen = LobbyScreen(controller: _controller!);
            break;
          case GamePhase.dealing:
            screen = const Scaffold(body: Center(child: CircularProgressIndicator()));
            break;
          case GamePhase.playing:
          case GamePhase.reveal:
          case GamePhase.roundEnd:
          case GamePhase.ended:
            screen = BoardScreen(controller: _controller!);
            break;
        }

        return MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                screen,
                if (kDebugMode) ...[
                  const NetworkOverlay(),
                  StateInspector(controller: _controller!),
                ],
              ],
            ),
          ),
          debugShowCheckedModeBanner: false,
          theme: AppTheme.darkTheme,
        );
      },
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    _nameController.dispose();
    super.dispose();
  }
}

class _EntryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _EntryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250, height: 60,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class HowToPlayDialog extends StatefulWidget {
  const HowToPlayDialog({super.key});

  @override
  State<HowToPlayDialog> createState() => _HowToPlayDialogState();
}

class _HowToPlayDialogState extends State<HowToPlayDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentPage = 0;

  final List<Map<String, String>> _rules = [
    {'title': 'THE SETUP', 'desc': 'Each player starts with 5 HP and a hand of 5 hidden cards.'},
    {'title': 'THE BLUFF', 'desc': 'Play a card face down and DECLARE its value. You can lie about it!'},
    {'title': 'CHALLENGE!', 'desc': 'The next player can either Believe (it becomes their turn) or Challenge (reveal the card).'},
    {'title': 'DAMAGE', 'desc': 'Caught bluffing? You take 1 DMG. Challenged a truth? The challenger takes 1 DMG.'},
    {'title': 'VICTORY', 'desc': 'The last player with HP remaining wins the game!'},
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(0.9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('HOW TO PLAY', style: TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4)),
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _controller,
                child: Column(
                  children: [
                    Text(_rules[_currentPage]['title']!, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text(
                      _rules[_currentPage]['desc']!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(onPressed: () => setState(() { _currentPage--; _controller.forward(from: 0); }), child: const Text('BACK'))
                  else
                    const SizedBox(width: 80),
                  if (_currentPage < _rules.length - 1)
                    ElevatedButton(onPressed: () => setState(() { _currentPage++; _controller.forward(from: 0); }), child: const Text('NEXT'))
                  else
                    ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('START')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
