import 'dart:convert';

/// Represents a MeckChat device (local or remote).
class Device {
  final String deviceId;
  String displayName;
  final String platform;
  DateTime lastSeen;
  bool isOnline;

  Device({
    required this.deviceId,
    required this.displayName,
    required this.platform,
    DateTime? lastSeen,
    this.isOnline = true,
  }) : lastSeen = lastSeen ?? DateTime.now();

  /// Converts the device presence to a JSON map for `presence_online`.
  Map<String, dynamic> toPresenceOnlineJson() {
    return {
      'type': 'presence_online',
      'protocol_version': 1,
      'device_id': deviceId,
      'display_name': displayName,
      'platform': platform.toLowerCase(),
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  /// Converts the device presence to a JSON string for `presence_online`.
  String toPresenceOnlineJsonString() {
    return jsonEncode(toPresenceOnlineJson());
  }

  /// Converts the device presence to a JSON map for `presence_offline`.
  Map<String, dynamic> toPresenceOfflineJson() {
    return {
      'type': 'presence_offline',
      'device_id': deviceId,
    };
  }

  /// Converts the device presence to a JSON string for `presence_offline`.
  String toPresenceOfflineJsonString() {
    return jsonEncode(toPresenceOfflineJson());
  }

  /// Parses a device from an incoming MQTT presence JSON map.
  static Device? fromPresenceJson(Map<String, dynamic> json) {
    final deviceId = json['device_id'] as String?;
    if (deviceId == null || deviceId.isEmpty) {
      return null;
    }

    final type = json['type'] as String? ?? 'presence_online';
    final isOnline = type == 'presence_online';
    final displayName = (json['display_name'] as String?) ?? 'Unknown Device';
    final platform = (json['platform'] as String?) ?? 'unknown';

    DateTime lastSeen = DateTime.now();
    if (json['timestamp'] != null) {
      final ts = json['timestamp'];
      if (ts is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
      }
    }

    return Device(
      deviceId: deviceId,
      displayName: displayName,
      platform: platform,
      lastSeen: lastSeen,
      isOnline: isOnline,
    );
  }

  /// Parses a device from an incoming MQTT payload string.
  static Device? fromPresencePayload(String payloadStr) {
    try {
      final decoded = jsonDecode(payloadStr);
      if (decoded is Map<String, dynamic>) {
        return fromPresenceJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
