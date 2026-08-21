import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/device.dart';

class MeckChatCoreService {
  static final MeckChatCoreService _instance = MeckChatCoreService._internal();
  factory MeckChatCoreService() => _instance;
  MeckChatCoreService._internal();

  LocalDevice? _localIdentity;
  LocalDevice? get localIdentity => _localIdentity;

  bool _isOnboarded = false;
  bool get isOnboarded => _isOnboarded;

  /// Detects real platform name from running host operating system
  static String detectPlatform() {
    if (kIsWeb) return 'Web';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    return 'Unknown';
  }

  /// Device Name Input Validator:
  /// - Minimum 1 char, Maximum 40 chars
  /// - Trim leading/trailing whitespace
  /// - Reject empty string or control characters
  static String? validateDeviceName(String? rawName) {
    if (rawName == null) return 'Device name is required.';
    final trimmed = rawName.trim();
    if (trimmed.isEmpty) return 'Device name cannot be empty.';
    if (trimmed.length > 40) return 'Device name must be 40 characters or fewer.';
    if (RegExp(r'[\x00-\x1F\x7F]').hasMatch(trimmed)) {
      return 'Device name contains invalid control characters.';
    }
    return null; // Valid
  }

  /// Initializes identity from SharedPreferences on app launch
  Future<bool> loadSavedIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    _isOnboarded = prefs.getBool('is_onboarded') ?? false;

    if (_isOnboarded) {
      final name = prefs.getString('device_name') ?? 'MeckChat Device';
      final deviceId = prefs.getString('device_id') ?? _generateDeviceId();
      final pubKey = prefs.getString('wireguard_public_key') ?? _generateKey();
      final privKey = prefs.getString('wireguard_private_key') ?? _generateKey();
      final virtualIp = prefs.getString('virtual_ip') ?? _generateVirtualIp(deviceId);
      final platform = detectPlatform();

      _localIdentity = LocalDevice(
        deviceId: deviceId,
        displayName: name,
        platform: platform,
        wireGuardPublicKey: pubKey,
        wireGuardPrivateKey: privKey,
        virtualIp: virtualIp,
        isMqttConnected: true,
      );
      return true;
    }
    return false;
  }

  /// Saves first-launch device identity to SharedPreferences
  Future<LocalDevice> createAndSaveIdentity(String name) async {
    final validationError = validateDeviceName(name);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final trimmedName = name.trim();
    final prefs = await SharedPreferences.getInstance();
    final deviceId = 'dev_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';
    final pubKey = 'wg_pub_${_generateKey()}';
    final privKey = 'wg_priv_${_generateKey()}';
    final virtualIp = _generateVirtualIp(deviceId);
    final platform = detectPlatform();

    await prefs.setBool('is_onboarded', true);
    await prefs.setString('device_name', trimmedName);
    await prefs.setString('device_id', deviceId);
    await prefs.setString('wireguard_public_key', pubKey);
    await prefs.setString('wireguard_private_key', privKey);
    await prefs.setString('virtual_ip', virtualIp);

    _isOnboarded = true;
    _localIdentity = LocalDevice(
      deviceId: deviceId,
      displayName: trimmedName,
      platform: platform,
      wireGuardPublicKey: pubKey,
      wireGuardPrivateKey: privKey,
      virtualIp: virtualIp,
      isMqttConnected: true,
    );

    return _localIdentity!;
  }

  /// Updates device name from Settings screen and saves to local storage
  Future<void> updateDeviceName(String newName) async {
    final validationError = validateDeviceName(newName);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }

    final trimmedName = newName.trim();
    if (_localIdentity != null) {
      _localIdentity = _localIdentity!.copyWith(displayName: trimmedName);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('device_name', trimmedName);
    }
  }

  /// Verifies WireGuard Private Key is NEVER published to HiveMQ or exported
  bool assertPrivateKeySafety() {
    if (_localIdentity == null) return true;
    final jsonStr = jsonEncode(_localIdentity!.toSignalingJson());
    return !jsonStr.contains('private_key') &&
        !jsonStr.contains(_localIdentity!.wireGuardPrivateKey);
  }

  static String _generateDeviceId() =>
      'dev_${const Uuid().v4().replaceAll('-', '').substring(0, 16)}';

  static String _generateKey() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  static String _generateVirtualIp(String deviceId) {
    final hash = deviceId.codeUnits.fold<int>(0, (sum, char) => sum + char);
    final hostOctet = (hash % 250) + 2;
    return '10.77.0.$hostOctet';
  }
}
