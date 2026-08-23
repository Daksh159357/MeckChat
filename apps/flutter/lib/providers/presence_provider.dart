import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/device.dart';
import '../services/mqtt_service.dart';
import '../services/p2p_chat_service.dart';
import '../services/paired_devices_service.dart';
import '../services/pairing_service.dart';

class PresenceProvider with ChangeNotifier {
  static const _vpnChannel = MethodChannel('com.meckchat/wireguard_vpn');

  LocalDevice? _localDevice;
  LocalDevice? get localDevice => _localDevice;

  final Map<String, PeerDevice> _remoteDevices = {};
  Timer? _expirationTimer;
  Timer? _handshakeMonitorTimer;

  /// Remote online devices list — populated ONLY from real MQTT presence messages.
  /// Strictly excludes local device identity and fake/mock devices.
  List<PeerDevice> get onlineDevices => _remoteDevices.values
      .where((d) => d.isOnline && _isDeviceFresh(d))
      .toList();

  /// List of paired/trusted devices for the dedicated Chats section
  List<PeerDevice> get pairedDevices =>
      PairedDevicesService().pairedDevices.values.toList();

  PresenceProvider() {
    _startStalePresenceCleanupTimer();
    _startHandshakeMonitoring();
    _loadPairedDevices();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
    _handshakeMonitorTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPairedDevices() async {
    await PairedDevicesService().loadPairedDevices();
    notifyListeners();
  }

  /// Sets local device identity and connects to real HiveMQ MQTT broker over TLS (8883)
  void setLocalIdentity(LocalDevice device) {
    _localDevice = device;
    notifyListeners();

    // Start local P2P WireGuard chat server socket listener on 10.77.x.x:51821
    P2PChatService().startListener();

    // Initialize MqttService and PairingService
    MqttService().onPresenceReceived = handleIncomingPresence;
    MqttService().initialize(localDevice: device);

    PairingService().initialize(device);
    PairingService().onPairingSuccess = () {
      notifyListeners();
    };
  }

  /// Updates local device name from Settings screen and broadcasts presence update
  void updateLocalDeviceName(String newName) {
    if (_localDevice != null) {
      _localDevice = _localDevice!.copyWith(displayName: newName);
      notifyListeners();
      MqttService().publishOnlinePresence();
    }
  }

  /// Refreshes local presence state and queries online peers over HiveMQ
  void refreshPresence() {
    _cleanupStalePeers();
    MqttService().publishOnlinePresence();
    MqttService().publishDiscoveryQuery();
    notifyListeners();
  }

  /// Handles incoming MQTT presence payload from HiveMQ topic
  void handleIncomingPresence(Map<String, dynamic> json) {
    final incomingDeviceId = json['device_id'] as String?;
    if (incomingDeviceId == null || incomingDeviceId.isEmpty) return;

    // RULE: Self device MUST NOT appear as a remote peer
    if (_localDevice != null && incomingDeviceId == _localDevice!.deviceId) {
      return;
    }

    final msgType =
        (json['type'] ?? json['msg_type'] ?? 'presence_online').toString().toLowerCase();

    if (msgType.contains('online')) {
      final isPaired = PairedDevicesService().isPaired(incomingDeviceId);
      final existingState = _remoteDevices[incomingDeviceId]?.wireGuardStatus ??
          (isPaired ? WireGuardTunnelState.connecting : WireGuardTunnelState.notConfigured);

      final peer = PeerDevice(
        deviceId: incomingDeviceId,
        displayName: json['display_name'] ?? 'Unknown Device',
        platform: json['platform'] ?? 'Unknown Platform',
        wireGuardPublicKey: json['wireguard_public_key'] ?? '',
        virtualIp: json['virtual_ip'] ?? '',
        isPaired: isPaired,
        isOnline: true,
        wireGuardStatus: existingState,
        lastSeen: DateTime.now(),
      );

      _remoteDevices[incomingDeviceId] = peer;

      if (isPaired) {
        PairedDevicesService().savePairedDevice(peer);
      }
    } else if (msgType.contains('offline')) {
      _remoteDevices.remove(incomingDeviceId);
    }
    notifyListeners();
  }

  /// Initiates P2P WireGuard tunnel setup and verifies real handshake & 10.77.x.x health check
  Future<void> connectToDevice(String deviceId) async {
    final peer = _remoteDevices[deviceId] ?? PairedDevicesService().getPairedDevice(deviceId);
    if (peer == null || _localDevice == null) return;

    _updatePeerWireGuardState(deviceId, WireGuardTunnelState.connecting);

    // 1. Configure Native Android / Desktop WireGuard Engine
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final isPrepared = await _vpnChannel.invokeMethod<bool>('prepareVpn');
        if (isPrepared == true) {
          await _vpnChannel.invokeMethod<bool>('startVpn', {
            'virtual_ip': _localDevice!.virtualIp,
            'private_key': _localDevice!.wireGuardPrivateKey,
            'peer_public_key': peer.wireGuardPublicKey,
            'peer_virtual_ip': peer.virtualIp,
          });
        }
      } catch (e) {
        debugPrint('Android WireGuard MethodChannel error: $e');
      }
    }

    _updatePeerWireGuardState(deviceId, WireGuardTunnelState.configured);

    // 2. Perform Real 10.77.x.x P2P Socket Health Check (HEALTH_PING / HEALTH_PONG) over WireGuard
    final isReachable = await P2PChatService().performWireGuardHealthCheck(peer.virtualIp);

    if (isReachable) {
      _updatePeerWireGuardState(deviceId, WireGuardTunnelState.connected);
      // Flush offline pending messages upon verified WireGuard connection
      await P2PChatService().flushPendingMessages(peer.deviceId, peer.virtualIp);
    } else {
      _updatePeerWireGuardState(deviceId, WireGuardTunnelState.disconnected);
    }
  }

  void _startHandshakeMonitoring() {
    _handshakeMonitorTimer?.cancel();
    _handshakeMonitorTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (_localDevice == null) return;

      for (final entry in _remoteDevices.entries) {
        final peer = entry.value;
        if (!peer.isPaired || peer.virtualIp.isEmpty) continue;

        // Verify Android Native WireGuard stats or socket reachability
        if (!kIsWeb && Platform.isAndroid) {
          try {
            final stats = await _vpnChannel.invokeMapMethod<String, dynamic>('getTunnelStats', {
              'peer_public_key': peer.wireGuardPublicKey,
            });
            if (stats != null && stats['status'] == 'Connected') {
              _updatePeerWireGuardState(peer.deviceId, WireGuardTunnelState.connected);
              continue;
            }
          } catch (_) {}
        }

        // Socket health check verification over 10.77.x.x:51821
        final isHealthy = await P2PChatService().performWireGuardHealthCheck(peer.virtualIp);
        if (isHealthy && peer.wireGuardStatus != WireGuardTunnelState.connected) {
          _updatePeerWireGuardState(peer.deviceId, WireGuardTunnelState.connected);
          await P2PChatService().flushPendingMessages(peer.deviceId, peer.virtualIp);
        } else if (!isHealthy && peer.wireGuardStatus == WireGuardTunnelState.connected) {
          _updatePeerWireGuardState(peer.deviceId, WireGuardTunnelState.disconnected);
        }
      }
    });
  }

  void _updatePeerWireGuardState(String deviceId, WireGuardTunnelState state) {
    if (_remoteDevices.containsKey(deviceId)) {
      _remoteDevices[deviceId] =
          _remoteDevices[deviceId]!.copyWith(wireGuardStatus: state);
      notifyListeners();
    }
  }

  void _startStalePresenceCleanupTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _cleanupStalePeers();
    });
  }

  void _cleanupStalePeers() {
    final now = DateTime.now();
    final initialCount = _remoteDevices.length;
    _remoteDevices.removeWhere(
        (id, peer) => now.difference(peer.lastSeen).inSeconds > 90);
    if (_remoteDevices.length != initialCount) {
      notifyListeners();
    }
  }

  bool _isDeviceFresh(PeerDevice device) {
    return DateTime.now().difference(device.lastSeen).inSeconds <= 90;
  }
}
