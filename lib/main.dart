import 'package:flutter/material.dart' hide ConnectionState;
import 'dart:io';
import 'dart:convert';
import 'package:nearby_connections/nearby_connections.dart';
import 'core/network/guest_manager.dart';
import 'core/network/host_manager.dart';
import 'core/network/network_manager.dart';
import 'core/utils/net_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Determine role from dart-define or platform default
  const String envRole = String.fromEnvironment('role');
  String role = envRole.isNotEmpty ? envRole.toLowerCase() : 'host';
  
  if (Platform.isLinux) {
    role = 'guest'; // Override for Linux testing if needed, though Nearby is Android-centric
  }

  runApp(MaterialApp(
    home: NearbyTestRunner(role: role),
    debugShowCheckedModeBanner: false,
  ));
}

class NearbyTestRunner extends StatefulWidget {
  final String role;
  const NearbyTestRunner({super.key, required this.role});

  @override
  State<NearbyTestRunner> createState() => _NearbyTestRunnerState();
}

class _NearbyTestRunnerState extends State<NearbyTestRunner> {
  late NetworkManager _networkManager;
  String _status = 'Initializing...';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _startNetworkLayer();
  }

  Future<void> _startNetworkLayer() async {
    try {
      setState(() => _status = 'Requesting Permissions...');
      
      if (widget.role == 'host' || widget.role == 'h') {
        _networkManager = HostManager();
      } else {
        _networkManager = GuestManager();
      }

      await _networkManager.initialize();
      setState(() => _status = 'Initialized. Starting ${widget.role}...');

      _networkManager.incomingPackets.listen((packet) {
        NetLogger.log('[${widget.role}] Received Packet: $packet');
      });

      if (widget.role == 'host' || widget.role == 'h') {
        await (_networkManager as HostManager).startAdvertising();
        _listenToConnection(true);
      } else {
        await (_networkManager as GuestManager).startDiscovery();
        _listenToConnection(false);
      }
    } catch (e) {
      NetLogger.error('Startup failed', e);
      setState(() => _status = 'Error: $e');
    }
  }

  void _listenToConnection(bool isHost) {
    // We hook into the Nearby connection state via the package directly 
    // to update the UI and trigger the handshake in this runner.
    
    // Note: Our managers already handle the auto-accept and ping. 
    // We use this listener primarily to update the local UI state.
    
    // Since nearby_connections 4.3.0 doesn't have a single stream for all connections,
    // we rely on the internal logs from managers or we can add an event bus.
    // For this test runner, we will monitor the logs and status strings.
    setState(() => _status = '${widget.role.toUpperCase()} Active - Searching...');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'ROLE: ${widget.role.toUpperCase()}',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            if (_isConnected)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Icon(Icons.check_circle, color: Colors.green, size: 48),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _networkManager.dispose();
    super.dispose();
  }
}
