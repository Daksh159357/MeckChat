import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:meckchat/models/device.dart';
import 'package:meckchat/services/mqtt_service.dart';

class PresenceProvider extends ChangeNotifier {
  static const String prefKeyDeviceId = 'meckchat_device_id';
  static const String prefKeyDeviceName = 'meckchat_device_name';

  final MqttService _mqttService;
  final SharedPreferences? _prefsOverride;

  Device? _localDevice;
  final Map<String, Device> _remoteDevices = {};
  Timer? _staleCleanupTimer;
  bool _isInitialized = false;

  PresenceProvider({
    MqttService? mqttService,
    SharedPreferences? prefs,
  })  : _mqttService = mqttService ?? MqttService(),
        _prefsOverride = prefs {
    _setupMqttCallbacks();
  }

  Device? get localDevice => _localDevice;
  MqttStatus get status => _mqttService.status;
  bool get isConnected => _mqttService.isConnected;
  bool get isInitialized => _isInitialized;

  /// Returns only real remote devices discovered over MQTT.
  List<Device> get onlineDevices {
    final now = DateTime.now();
    return _remoteDevices.values
        .where((d) => d.isOnline && now.difference(d.lastSeen).inSeconds <= 90)
        .toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }

  void _setupMqttCallbacks() {
    _mqttService.onStatusChanged = (newStatus) {
      notifyListeners();
    };

    _mqttService.onDevicePresenceReceived = (device) {
      // Do not add self
      if (_localDevice != null && device.deviceId == _localDevice!.deviceId) {
        return;
      }

      device.lastSeen = DateTime.now();
      device.isOnline = true;
      _remoteDevices[device.deviceId] = device;
      debugPrint('[MQTT] Remote peer added/updated: ${device.displayName} (${device.platform})');
      notifyListeners();
    };

    _mqttService.onDeviceOfflineReceived = (deviceId) {
      if (_remoteDevices.containsKey(deviceId)) {
        _remoteDevices.remove(deviceId);
        debugPrint('[MQTT] Remote peer removed (offline): id=$deviceId');
        notifyListeners();
      }
    };
  }

  /// Initializes the local device identity and connects to MQTT.
  Future<void> initialize() async {
    if (_isInitialized) return;

    final prefs = _prefsOverride ?? await SharedPreferences.getInstance();

    // 1. Get or generate persistent Device ID
    var deviceId = prefs.getString(prefKeyDeviceId);
    if (deviceId == null || deviceId.isEmpty) {
      deviceId = 'mc_${const Uuid().v4()}';
      await prefs.setString(prefKeyDeviceId, deviceId);
      debugPrint('[Identity] Generated new persistent Device ID: $deviceId');
    } else {
      debugPrint('[Identity] Loaded persistent Device ID: $deviceId');
    }

    // 2. Determine platform
    String platformStr = 'linux';
    if (!kIsWeb) {
      try {
        if (Platform.isAndroid) {
          platformStr = 'android';
        } else if (Platform.isLinux) {
          platformStr = 'linux';
        } else if (Platform.isWindows) {
          platformStr = 'windows';
        } else if (Platform.isMacOS) {
          platformStr = 'macos';
        }
      } catch (_) {
        platformStr = 'linux';
      }
    }

    // 3. Get or set default Device Name
    var deviceName = prefs.getString(prefKeyDeviceName);
    if (deviceName == null || deviceName.isEmpty) {
      deviceName = platformStr == 'android' ? 'Android Phone' : 'Linux Laptop';
      await prefs.setString(prefKeyDeviceName, deviceName);
    }

    _localDevice = Device(
      deviceId: deviceId,
      displayName: deviceName,
      platform: platformStr,
    );

    _isInitialized = true;
    notifyListeners();

    // 4. Start periodic cleanup of stale peers (every 15s)
    _startStaleCleanupTimer();

    // 5. Connect to MQTT
    await _mqttService.connect(_localDevice!);
  }

  /// Updates the display name of this device persistently and republishes presence.
  Future<void> setDeviceName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty || _localDevice == null) return;

    _localDevice!.displayName = trimmed;
    final prefs = _prefsOverride ?? await SharedPreferences.getInstance();
    await prefs.setString(prefKeyDeviceName, trimmed);

    debugPrint('[Identity] Updated Device Name to: $trimmed');
    _mqttService.publishOnlinePresence();
    notifyListeners();
  }

  /// Triggers a manual MQTT reconnect.
  Future<void> reconnect() async {
    if (_localDevice != null) {
      _mqttService.disconnect();
      await _mqttService.connect(_localDevice!);
    }
  }

  /// Starts the 15-second timer to clean up peers that haven't sent a heartbeat in >90s.
  void _startStaleCleanupTimer() {
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _cleanupStalePeers();
    });
  }

  void _cleanupStalePeers() {
    final now = DateTime.now();
    final initialCount = _remoteDevices.length;
    _remoteDevices.removeWhere(
        (id, peer) => now.difference(peer.lastSeen).inSeconds > 90);

    if (_remoteDevices.length != initialCount) {
      debugPrint('[MQTT] Cleaned up ${initialCount - _remoteDevices.length} stale peer(s)');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _staleCleanupTimer?.cancel();
    _mqttService.dispose();
    super.dispose();
  }
}
