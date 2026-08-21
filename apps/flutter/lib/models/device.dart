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

class MeckDevice {
  final String deviceId;
  final String displayName;
  final String platform;
  final String wireGuardPublicKey;
  final String virtualIp;
  final bool isPaired;
  final MeckConnectionState state;
  final DateTime lastSeen;

  MeckDevice({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    required this.wireGuardPublicKey,
    required this.virtualIp,
    this.isPaired = false,
    this.state = MeckConnectionState.online,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();

  factory MeckDevice.fromJson(Map<String, dynamic> json) {
    return MeckDevice(
      deviceId: json['device_id'] ?? '',
      displayName: json['display_name'] ?? 'Unknown Device',
      platform: json['platform'] ?? 'Unknown Platform',
      wireGuardPublicKey: json['wireguard_public_key'] ?? '',
      virtualIp: json['virtual_ip'] ?? '',
      isPaired: json['is_paired'] ?? false,
      state: MeckConnectionState.online,
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

  MeckDevice copyWith({
    bool? isPaired,
    MeckConnectionState? state,
    DateTime? lastSeen,
  }) {
    return MeckDevice(
      deviceId: deviceId,
      displayName: displayName,
      platform: platform,
      wireGuardPublicKey: wireGuardPublicKey,
      virtualIp: virtualIp,
      isPaired: isPaired ?? this.isPaired,
      state: state ?? this.state,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
