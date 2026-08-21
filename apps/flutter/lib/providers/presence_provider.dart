import 'package:flutter/foundation.dart';
import '../models/device.dart';

class PresenceProvider with ChangeNotifier {
  final Map<String, MeckDevice> _devices = {};

  List<MeckDevice> get onlineDevices =>
      _devices.values.where((d) => d.state != MeckConnectionState.offline).toList();

  void initMockPresence() {
    _devices['pc_1'] = MeckDevice(
      deviceId: '7f3a91b2c4e5001',
      displayName: 'Daksh-PC',
      platform: 'Windows',
      wireGuardPublicKey: 'pub_key_pc_windows_x25519',
      virtualIp: '10.77.0.2',
      state: MeckConnectionState.online,
    );

    _devices['phone_1'] = MeckDevice(
      deviceId: '7f3a91b2c4e5002',
      displayName: 'Daksh-Phone',
      platform: 'Android',
      wireGuardPublicKey: 'pub_key_phone_android_x25519',
      virtualIp: '10.77.0.3',
      state: MeckConnectionState.online,
    );

    _devices['laptop_1'] = MeckDevice(
      deviceId: '7f3a91b2c4e5003',
      displayName: 'Linux-Laptop',
      platform: 'Linux',
      wireGuardPublicKey: 'pub_key_laptop_linux_x25519',
      virtualIp: '10.77.0.4',
      state: MeckConnectionState.online,
    );

    notifyListeners();
  }

  Future<void> connectToDevice(String deviceId) async {
    final device = _devices[deviceId];
    if (device == null) return;

    _updateState(deviceId, MeckConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 600));

    _updateState(deviceId, MeckConnectionState.authenticating);
    await Future.delayed(const Duration(milliseconds: 600));

    _updateState(deviceId, MeckConnectionState.configuringWireGuard);
    await Future.delayed(const Duration(milliseconds: 600));

    _updateState(deviceId, MeckConnectionState.establishingTunnel);
    await Future.delayed(const Duration(milliseconds: 600));

    _updateState(deviceId, MeckConnectionState.connected);
  }

  void _updateState(String deviceId, MeckConnectionState state) {
    if (_devices.containsKey(deviceId)) {
      _devices[deviceId] = _devices[deviceId]!.copyWith(state: state);
      notifyListeners();
    }
  }
}
