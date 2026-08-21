import 'dart:convert';

enum WireGuardTunnelState {
  notConfigured,
  configured,
  connecting,
  connected,
  disconnected,
  failed,
}

extension WireGuardTunnelStateX on WireGuardTunnelState {
  String get label {
    switch (this) {
      case WireGuardTunnelState.notConfigured:
        return 'Not Configured';
      case WireGuardTunnelState.configured:
        return 'Configured';
      case WireGuardTunnelState.connecting:
        return 'Connecting...';
      case WireGuardTunnelState.connected:
        return 'Connected (WireGuard P2P)';
      case WireGuardTunnelState.disconnected:
        return 'Disconnected';
      case WireGuardTunnelState.failed:
        return 'Connection Failed';
    }
  }
}

enum MeckConnectionState {
  offline,
  online,
  connecting,
  authenticating,
  configuringWireGuard,
  establishingTunnel,
  connected,
  disconnected,
  connectionFailed,
}

extension MeckConnectionStateX on MeckConnectionState {
  String get label {
    switch (this) {
      case MeckConnectionState.offline:
        return 'Offline';
      case MeckConnectionState.online:
        return 'Online';
      case MeckConnectionState.connecting:
        return 'Connecting...';
      case MeckConnectionState.authenticating:
        return 'Authenticating...';
      case MeckConnectionState.configuringWireGuard:
        return 'Configuring WireGuard...';
      case MeckConnectionState.establishingTunnel:
        return 'Establishing Tunnel...';
      case MeckConnectionState.connected:
        return 'Connected (WireGuard P2P)';
      case MeckConnectionState.disconnected:
        return 'Disconnected';
      case MeckConnectionState.connectionFailed:
        return 'Connection Failed';
    }
  }
}

/// Represents the Local Device identity running on this physical machine
class LocalDevice {
  final String deviceId;
  final String displayName;
  final String platform;
  final String wireGuardPublicKey;
  final String wireGuardPrivateKey; // Local only, NEVER sent over network or QR
  final String virtualIp;
  final bool isMqttConnected;
  final WireGuardTunnelState wireGuardStatus;

  LocalDevice({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.wireGuardPublicKey,
    required this.wireGuardPrivateKey,
    required this.virtualIp,
    this.isMqttConnected = false,
    this.wireGuardStatus = WireGuardTunnelState.disconnected,
  });

  LocalDevice copyWith({
    String? displayName,
    bool? isMqttConnected,
    WireGuardTunnelState? wireGuardStatus,
  }) {
    return LocalDevice(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      platform: platform,
      wireGuardPublicKey: wireGuardPublicKey,
      wireGuardPrivateKey: wireGuardPrivateKey,
      virtualIp: virtualIp,
      isMqttConnected: isMqttConnected ?? this.isMqttConnected,
      wireGuardStatus: wireGuardStatus ?? this.wireGuardStatus,
    );
  }

  /// Safe JSON serialization for signaling — NEVER includes private key
  Map<String, dynamic> toSignalingJson() => {
        'type': 'presence_online',
        'device_id': deviceId,
        'display_name': displayName,
        'platform': platform,
        'protocol_version': 1,
        'wireguard_public_key': wireGuardPublicKey,
        'virtual_ip': virtualIp,
      };

  /// Asserts that no private key or raw secret exists in JSON output
  bool assertPrivateKeySafety() {
    final jsonStr = jsonEncode(toSignalingJson());
    return !jsonStr.contains('private_key') && !jsonStr.contains(wireGuardPrivateKey);
  }
}

/// Represents a Remote Peer discovered via real MQTT presence messages
class PeerDevice {
  final String deviceId;
  final String displayName;
  final String platform;
  final String wireGuardPublicKey;
  final String virtualIp;
  final bool isPaired;
  final bool isOnline;
  final WireGuardTunnelState wireGuardStatus;
  final DateTime lastSeen;

  PeerDevice({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.wireGuardPublicKey,
    required this.virtualIp,
    this.isPaired = false,
    this.isOnline = true,
    this.wireGuardStatus = WireGuardTunnelState.notConfigured,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  factory PeerDevice.fromJson(Map<String, dynamic> json) {
    return PeerDevice(
      deviceId: json['device_id'] ?? '',
      displayName: json['display_name'] ?? 'Unknown Device',
      platform: json['platform'] ?? 'Unknown Platform',
      wireGuardPublicKey: json['wireguard_public_key'] ?? '',
      virtualIp: json['virtual_ip'] ?? '',
      isPaired: json['is_paired'] ?? false,
      isOnline: true,
      wireGuardStatus: WireGuardTunnelState.notConfigured,
      lastSeen: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'display_name': displayName,
        'platform': platform,
        'wireguard_public_key': wireGuardPublicKey,
        'virtual_ip': virtualIp,
        'is_paired': isPaired,
      };

  PeerDevice copyWith({
    String? displayName,
    bool? isPaired,
    bool? isOnline,
    WireGuardTunnelState? wireGuardStatus,
    DateTime? lastSeen,
  }) {
    return PeerDevice(
      deviceId: deviceId,
      displayName: displayName ?? this.displayName,
      platform: platform,
      wireGuardPublicKey: wireGuardPublicKey,
      virtualIp: virtualIp,
      isPaired: isPaired ?? this.isPaired,
      isOnline: isOnline ?? this.isOnline,
      wireGuardStatus: wireGuardStatus ?? this.wireGuardStatus,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}

/// Backward compatibility alias mapping to PeerDevice for UI components
typedef MeckDevice = PeerDevice;
