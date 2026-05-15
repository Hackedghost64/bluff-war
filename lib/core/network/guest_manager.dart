import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/net_logger.dart';
import 'network_manager.dart';

class GuestManager implements NetworkManager {
  final Strategy strategy = Strategy.P2P_POINT_TO_POINT;
  final String serviceId = "com.example.ble_network";
  String? _connectedEndpointId;
  
  final StreamController<Map<String, dynamic>> _packetController = StreamController.broadcast();

  bool get isConnected => _connectedEndpointId != null;

  @override
  Stream<Map<String, dynamic>> get incomingPackets => _packetController.stream;

  @override
  Future<void> initialize() async {
    NetLogger.log('Initializing GuestManager (Discoverer)...');
    
    final permissions = [
      Permission.location,
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.nearbyWifiDevices,
    ];

    Map<Permission, PermissionStatus> statuses = await permissions.request();
    if (statuses.values.any((s) => !s.isGranted)) {
      NetLogger.error('Missing permissions: ${statuses.entries.where((e) => !e.value.isGranted).map((e) => e.key).toList()}');
      throw Exception('Permissions denied');
    }

    NetLogger.log('GuestManager initialized and permissions granted');
  }

  Future<void> startDiscovery() async {
    NetLogger.log('Discovery -> Starting discovery for serviceId: $serviceId');
    
    try {
      await Nearby().startDiscovery(
        "GuestDevice",
        strategy,
        onEndpointFound: (id, name, serviceId) async {
          NetLogger.log('Endpoint Found -> $id ($name)');
          await stopDiscovery();
          
          NetLogger.log('Connecting -> $id');
          await _requestConnection(id);
        },
        onEndpointLost: (id) {
          NetLogger.log('Endpoint Lost -> $id');
        },
        serviceId: serviceId,
      );
    } catch (e) {
      NetLogger.error('Discovery failed to start', e);
    }
  }

  Future<void> stopDiscovery() async {
    NetLogger.log('Discovery -> Stopping discovery');
    await Nearby().stopDiscovery();
  }

  Future<void> _requestConnection(String endpointId) async {
    try {
      await Nearby().requestConnection(
        "GuestDevice",
        endpointId,
        onConnectionInitiated: (id, info) async {
          NetLogger.log('Connection Initiated -> $id (Token: ${info.authenticationToken})');
          await Nearby().acceptConnection(
            id,
            onPayLoadRecieved: (id, payload) {
              if (payload.type == PayloadType.BYTES) {
                _processIncomingData(payload.bytes!);
              }
            },
          );
        },
        onConnectionResult: (id, status) {
          NetLogger.log('Connection Result -> $id: $status');
          if (status == Status.CONNECTED) {
            _connectedEndpointId = id;
            NetLogger.log('Connected to $id. Sending ping in 1s...');
            Future.delayed(const Duration(milliseconds: 1000), () {
              sendPacket({
                "type": "ping",
                "role": "guest",
                "timestamp": DateTime.now().toIso8601String(),
              });
            });
          }
        },
        onDisconnected: (id) {
          NetLogger.log('Disconnected from $id');

          if (!_packetController.isClosed) {
            _packetController.add({
              'type': 'system_disconnect',
              'data': {},
            });
          } else {
            NetLogger.critical('Stream closed before disconnect packet could be injected.');
          }

          if (_connectedEndpointId == id) _connectedEndpointId = null;
        },
      );
    } catch (e) {
      NetLogger.error('Connection request failed', e);
    }
  }

  void _processIncomingData(Uint8List bytes) {
    try {
      final jsonString = utf8.decode(bytes);
      final payload = json.decode(jsonString) as Map<String, dynamic>;
      _packetController.add(payload);
    } catch (e) {
      NetLogger.error('Failed to parse incoming packet', e);
    }
  }

  @override
  Future<void> sendPacket(Map<String, dynamic> payload) async {
    if (_connectedEndpointId == null) {
      NetLogger.error('Cannot send packet: Not connected');
      return;
    }

    try {
      final jsonString = json.encode(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));
      
      await Nearby().sendBytesPayload(_connectedEndpointId!, bytes);
      NetLogger.log('Packet sent: $jsonString');
    } catch (e) {
      NetLogger.error('Failed to send packet', e);
    }
  }

  @override
  Future<void> dispose() async {
    NetLogger.log('Disposing GuestManager...');
    await stopDiscovery();
    if (_connectedEndpointId != null) {
      await Nearby().disconnectFromEndpoint(_connectedEndpointId!);
      _connectedEndpointId = null;
    }
    await _packetController.close();
  }
}
