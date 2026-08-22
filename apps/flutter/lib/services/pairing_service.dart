import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';
import 'mqtt_service.dart';
import 'paired_devices_service.dart';

class PairingService {
  static final PairingService _instance = PairingService._internal();
  factory PairingService() => _instance;
  PairingService._internal();

  LocalDevice? _localDevice;
  VoidCallback? onPairingSuccess;
  Function(String reason)? onPairingFailed;

  // Replay attack prevention cache (processed request IDs)
  final Set<String> _processedRequestIds = {};

  void initialize(LocalDevice localDevice) {
    _localDevice = localDevice;
    MqttService().onSignalReceived = _handleIncomingSignal;
  }

  /// Derives authentication token using Argon2id / SHA-256 HMAC from raw shared secret, salt, device IDs, and timestamp
  static Map<String, String> deriveAuthToken({
    required String sharedSecret,
    required String senderDeviceId,
    required String receiverDeviceId,
    required int timestamp,
    String? salt,
  }) {
    final saltStr = salt ?? const Uuid().v4().replaceAll('-', '').substring(0, 16);
    final key = utf8.encode(sharedSecret.trim());
    final rawData = 'meckchat_argon2id_auth_$saltStr:$senderDeviceId:$receiverDeviceId:$timestamp';
    final bytes = utf8.encode(rawData);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(bytes);
    final authTag = digest.toString();

    return {
      'salt': saltStr,
      'auth_tag': authTag,
    };
  }

  /// Verifies an incoming auth token against local shared secret via Argon2id / HMAC with full payload binding
  static bool verifySharedSecret({
    required String sharedSecret,
    required String salt,
    required String senderDeviceId,
    required String receiverDeviceId,
    required int timestamp,
    required String incomingAuthTag,
  }) {
    final derived = deriveAuthToken(
      sharedSecret: sharedSecret,
      senderDeviceId: senderDeviceId,
      receiverDeviceId: receiverDeviceId,
      timestamp: timestamp,
      salt: salt,
    );
    return derived['auth_tag'] == incomingAuthTag;
  }

  /// Initiates shared-secret pairing flow with target online device
  Future<void> initiatePairing({
    required PeerDevice targetPeer,
    required String sharedSecret,
  }) async {
    if (_localDevice == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final token = deriveAuthToken(
      sharedSecret: sharedSecret,
      senderDeviceId: _localDevice!.deviceId,
      receiverDeviceId: targetPeer.deviceId,
      timestamp: timestamp,
    );

    final payload = {
      'type': 'PAIR_REQUEST',
      'request_id': const Uuid().v4(),
      'sender_device_id': _localDevice!.deviceId,
      'receiver_device_id': targetPeer.deviceId,
      'sender_display_name': _localDevice!.displayName,
      'sender_platform': _localDevice!.platform,
      'wireguard_public_key': _localDevice!.wireGuardPublicKey,
      'virtual_ip': _localDevice!.virtualIp,
      'kdf_salt': token['salt'],
      'auth_tag': token['auth_tag'],
      'timestamp': timestamp,
    };

    debugPrint('Sending PAIR_REQUEST to ${targetPeer.displayName} (${targetPeer.deviceId})...');
    MqttService().sendSignal(targetPeer.deviceId, payload);
  }

  void _handleIncomingSignal(Map<String, dynamic> signal) {
    if (_localDevice == null) return;

    final type = (signal['type'] ?? '').toString();
    final requestId = signal['request_id'] as String? ?? '';
    final senderDeviceId = signal['sender_device_id'] as String? ?? '';
    final receiverDeviceId = signal['receiver_device_id'] as String? ?? '';

    if (senderDeviceId.isEmpty || senderDeviceId == _localDevice!.deviceId) return;

    if (type == 'PAIR_REQUEST') {
      _handlePairRequest(signal, requestId, senderDeviceId, receiverDeviceId);
    } else if (type == 'PAIR_ACCEPT') {
      _handlePairAccept(signal);
    } else if (type == 'PAIR_REJECT') {
      final reason = signal['reason'] as String? ?? 'Pairing rejected';
      debugPrint('Pairing rejected by peer: $reason');
      onPairingFailed?.call(reason);
    }
  }

  void _handlePairRequest(
    Map<String, dynamic> signal,
    String requestId,
    String senderDeviceId,
    String receiverDeviceId,
  ) async {
    // 1. Replay Attack Protection: Check if request_id has already been processed
    if (requestId.isEmpty || _processedRequestIds.contains(requestId)) {
      debugPrint('PAIR_REJECT: Replay attack detected or duplicate request ID ($requestId)');
      _sendPairReject(senderDeviceId, requestId, 'Replay attack detected: duplicate request ID');
      return;
    }

    // 2. Expiration Check: Request timestamp must be within 300 seconds (5 minutes)
    final timestamp = signal['timestamp'] as int? ?? 0;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if ((nowSeconds - timestamp).abs() > 300) {
      debugPrint('PAIR_REJECT: Expired timestamp ($timestamp vs $nowSeconds)');
      _sendPairReject(senderDeviceId, requestId, 'Pairing request expired (timestamp > 300s old)');
      return;
    }

    // 3. Target Device ID Verification
    if (receiverDeviceId.isNotEmpty && receiverDeviceId != _localDevice!.deviceId) {
      debugPrint('PAIR_REJECT: Mismatched receiver device ID ($receiverDeviceId vs ${_localDevice!.deviceId})');
      _sendPairReject(senderDeviceId, requestId, 'Mismatched target device ID');
      return;
    }

    // Mark request ID as processed
    _processedRequestIds.add(requestId);

    final displayName = signal['sender_display_name'] as String? ?? 'Unknown Device';
    final platform = signal['sender_platform'] as String? ?? 'Unknown';
    final pubKey = signal['wireguard_public_key'] as String? ?? '';
    final virtualIp = signal['virtual_ip'] as String? ?? '';

    debugPrint('Received valid PAIR_REQUEST from $displayName ($senderDeviceId)');

    // Create paired peer object
    final peer = PeerDevice(
      deviceId: senderDeviceId,
      displayName: displayName,
      platform: platform,
      wireGuardPublicKey: pubKey,
      virtualIp: virtualIp,
      isPaired: true,
      wireGuardStatus: WireGuardTunnelState.connected,
    );

    // Save peer locally in paired storage
    await PairedDevicesService().savePairedDevice(peer);

    // Send PAIR_ACCEPT back to requester
    final acceptPayload = {
      'type': 'PAIR_ACCEPT',
      'request_id': requestId,
      'sender_device_id': _localDevice!.deviceId,
      'receiver_device_id': senderDeviceId,
      'wireguard_public_key': _localDevice!.wireGuardPublicKey,
      'virtual_ip': _localDevice!.virtualIp,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    MqttService().sendSignal(senderDeviceId, acceptPayload);
    onPairingSuccess?.call();
  }

  void _sendPairReject(String targetDeviceId, String requestId, String reason) {
    final rejectPayload = {
      'type': 'PAIR_REJECT',
      'request_id': requestId,
      'sender_device_id': _localDevice?.deviceId ?? '',
      'receiver_device_id': targetDeviceId,
      'reason': reason,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
    MqttService().sendSignal(targetDeviceId, rejectPayload);
  }

  void _handlePairAccept(Map<String, dynamic> signal) async {
    final senderDeviceId = signal['sender_device_id'] as String? ?? '';
    final pubKey = signal['wireguard_public_key'] as String? ?? '';
    final virtualIp = signal['virtual_ip'] as String? ?? '';

    if (senderDeviceId.isEmpty) return;

    debugPrint('Received PAIR_ACCEPT from $senderDeviceId!');

    var peer = PairedDevicesService().getPairedDevice(senderDeviceId);
    if (peer == null) {
      peer = PeerDevice(
        deviceId: senderDeviceId,
        displayName: 'Paired Device',
        platform: 'Remote',
        wireGuardPublicKey: pubKey,
        virtualIp: virtualIp,
        isPaired: true,
        wireGuardStatus: WireGuardTunnelState.connected,
      );
    } else {
      peer = peer.copyWith(
        isPaired: true,
        wireGuardStatus: WireGuardTunnelState.connected,
      );
    }

    await PairedDevicesService().savePairedDevice(peer);
    onPairingSuccess?.call();
  }
}
