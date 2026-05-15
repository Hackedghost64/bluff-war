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
  late String _currentRole;
  String _status = 'Initializing...';
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    _startNetworkLayer();
  }

  Future<void> _startNetworkLayer() async {
    try {
      setState(() => _status = 'Requesting Permissions...');
      
      if (_currentRole == 'host' || _currentRole == 'h') {
        _networkManager = HostManager();
      } else {
        _networkManager = GuestManager();
      }

      await _networkManager.initialize();
      setState(() => _status = 'Initialized. Starting $_currentRole...');

      _networkManager.incomingPackets.listen((packet) {
        NetLogger.log('[$_currentRole] Received Packet: $packet');
        if (packet['type'] == 'ping') {
          setState(() => _isConnected = true);
        }
      });

      if (_currentRole == 'host' || _currentRole == 'h') {
        await (_networkManager as HostManager).startAdvertising();
      } else {
        await (_networkManager as GuestManager).startDiscovery();
      }
      setState(() => _status = '${_currentRole.toUpperCase()} Active - Searching...');
    } catch (e) {
      NetLogger.error('Startup failed', e);
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _toggleRole() async {
    setState(() => _status = 'Stopping current role...');
    await _networkManager.dispose();
    setState(() {
      _currentRole = (_currentRole == 'host') ? 'guest' : 'host';
      _isConnected = false;
    });
    await _startNetworkLayer();
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
              'ROLE: ${_currentRole.toUpperCase()}',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Text(
              _status,
              style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _toggleRole,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800]),
              child: Text('SWITCH TO ${(_currentRole == 'host') ? 'GUEST' : 'HOST'}'),
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
