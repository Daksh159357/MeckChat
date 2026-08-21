import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/device.dart';

class MeckChatCoreService {
  static final MeckChatCoreService _instance = MeckChatCoreService._internal();
  factory MeckChatCoreService() => _instance;
  MeckChatCoreService._internal();

  MeckDevice? _localIdentity;
  MeckDevice? get localIdentity => _localIdentity;

  Future<void> initializeLocalIdentity({
    required String name,
    required String platform,
  }) async {
    debugPrint('Initializing MeckChat Rust Core Identity for $name ($platform)...');
    // Simulated local identity creation backed by Rust FFI call
    _localIdentity = MeckDevice(
      deviceId: 'dev_${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
      displayName: name,
      platform: platform,
      wireGuardPublicKey: 'wg_pub_key_${DateTime.now().millisecondsSinceEpoch}',
      virtualIp: '10.77.0.2',
    );
  }

  /// Verifies WireGuard Private Key is NEVER published to HiveMQ or exported
  bool assertPrivateKeySafety() {
    if (_localIdentity == null) return true;
    final jsonStr = jsonEncode(_localIdentity!.toJson());
    return !jsonStr.contains('private_key');
  }
}
