import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/net_logger.dart';
import 'ble_protocol.dart';
import 'network_manager.dart';

class HostManager implements NetworkManager {
  final Strategy strategy = Strategy.P2P_POINT_TO_POINT;
  final String serviceId = "com.example.ble_network";
  final List<String> _connectedEndpoints = [];

  final StreamController<Map<String, dynamic>> _packetController =
      StreamController.broadcast();

  @override
  bool get isConnected => _connectedEndpoints.isNotEmpty;

  @override
  bool get isHost => true;

  @override
  Stream<Map<String, dynamic>> get incomingPackets => _packetController.stream;

  @override
  Future<void> initialize() async {
    NetLogger.log('Initializing HostManager (Advertiser)...');

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
      NetLogger.error(
        'Missing permissions: ${statuses.entries.where((e) => !e.value.isGranted).map((e) => e.key).toList()}',
      );
      throw Exception('Permissions denied');
    }

    NetLogger.log('HostManager initialized and permissions granted');
  }

  Future<void> startAdvertising() async {
    NetLogger.log(
      'Advertising -> Starting advertising for serviceId: $serviceId',
    );

    try {
      await Nearby().startAdvertising(
        "HostDevice",
        strategy,
        onConnectionInitiated: (id, info) async {
          NetLogger.log(
            'Connection Initiated -> $id (Token: ${info.authenticationToken})',
          );
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
            if (!_connectedEndpoints.contains(id)) {
              _connectedEndpoints.add(id);
            }
            
            // Inject local connection event
            _packetController.add(BleProtocol.createPacket('system_connected', data: {'endpointId': id}));

            NetLogger.log('Connected to $id. Sending ping in 1s...');
            Future.delayed(const Duration(milliseconds: 1000), () {
              sendPacket(
                BleProtocol.createPacket('ping', data: {'role': 'host'}),
              );
            });
          }
        },
        onDisconnected: (id) {
          NetLogger.log('Disconnected from $id');
          _connectedEndpoints.remove(id);

          if (!_packetController.isClosed) {
            _packetController.add(
              BleProtocol.createPacket('system_disconnect'),
            );
          }
        },
        serviceId: serviceId,
      );
    } catch (e) {
      NetLogger.error('Advertising failed to start', e);
    }
  }

  Future<void> stopAdvertising() async {
    NetLogger.log('Advertising -> Stopping advertising');
    await Nearby().stopAdvertising();
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
    if (_connectedEndpoints.isEmpty) {
      NetLogger.error('Cannot send packet: Not connected');
      return;
    }

    try {
      final jsonString = json.encode(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonString));

      for (var endpointId in _connectedEndpoints) {
        await Nearby().sendBytesPayload(endpointId, bytes);
      }
      NetLogger.log('Packet broadcasted to ${_connectedEndpoints.length} peers');
    } catch (e) {
      NetLogger.error('Failed to send packet', e);
    }
  }

  @override
  Future<void> dispose() async {
    NetLogger.log('Disposing HostManager...');
    await stopAdvertising();
    for (var endpointId in _connectedEndpoints) {
      await Nearby().disconnectFromEndpoint(endpointId);
    }
    _connectedEndpoints.clear();
    await _packetController.close();
  }
}
