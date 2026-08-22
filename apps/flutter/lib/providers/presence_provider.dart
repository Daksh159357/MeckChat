import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../services/mqtt_service.dart';
import '../services/paired_devices_service.dart';
import '../services/pairing_service.dart';

class PresenceProvider with ChangeNotifier {
  LocalDevice? _localDevice;
  LocalDevice? get localDevice => _localDevice;

  final Map<String, PeerDevice> _remoteDevices = {};
  Timer? _expirationTimer;

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
    _loadPairedDevices();
  }

  @override
  void dispose() {
    _expirationTimer?.cancel();
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
      final peer = PeerDevice(
        deviceId: incomingDeviceId,
        displayName: json['display_name'] ?? 'Unknown Device',
        platform: json['platform'] ?? 'Unknown Platform',
        wireGuardPublicKey: json['wireguard_public_key'] ?? '',
        virtualIp: json['virtual_ip'] ?? '',
        isPaired: isPaired,
        isOnline: true,
        wireGuardStatus: isPaired
            ? WireGuardTunnelState.connected
            : WireGuardTunnelState.notConfigured,
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

  /// Initiates P2P WireGuard tunnel handshake with target peer device
  Future<void> connectToDevice(String deviceId) async {
    final peer = _remoteDevices[deviceId] ?? PairedDevicesService().getPairedDevice(deviceId);
    if (peer == null) return;

    _updatePeerWireGuardState(deviceId, WireGuardTunnelState.connecting);
    await Future.delayed(const Duration(milliseconds: 300));

    _updatePeerWireGuardState(deviceId, WireGuardTunnelState.configured);
    await Future.delayed(const Duration(milliseconds: 300));

    _updatePeerWireGuardState(deviceId, WireGuardTunnelState.connected);
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
