import 'package:flutter_test/flutter_test.dart';
import 'package:meckchat/models/device.dart';
import 'package:meckchat/providers/presence_provider.dart';
import 'package:meckchat/services/mqtt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockMqttService extends MqttService {
  bool connectCalled = false;
  bool disconnectCalled = false;
  bool publishPresenceCalled = false;
  bool publishDiscoveryCalled = false;

  @override
  Future<void> connect(Device localDevice) async {
    connectCalled = true;
    setLocalDevice(localDevice);
  }

  @override
  void disconnect() {
    disconnectCalled = true;
  }

  @override
  void publishOnlinePresence() {
    publishPresenceCalled = true;
  }

  @override
  void publishDiscoveryRequest() {
    publishDiscoveryCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PresenceProvider Tests', () {
    late MockMqttService mockMqtt;
    PresenceProvider? activeProvider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      mockMqtt = MockMqttService();
    });

    tearDown(() {
      activeProvider?.dispose();
      activeProvider = null;
    });

    test('Device ID is generated with mc_ prefix and persisted across restarts', () async {
      final provider1 = PresenceProvider(mqttService: mockMqtt);
      activeProvider = provider1;
      await provider1.initialize();

      expect(provider1.localDevice, isNotNull);
      final id1 = provider1.localDevice!.deviceId;
      expect(id1.startsWith('mc_'), isTrue);
      expect(id1.length, greaterThan(10));

      provider1.dispose();

      // Re-initialize with same storage to verify persistence
      final provider2 = PresenceProvider(mqttService: mockMqtt);
      activeProvider = provider2;
      await provider2.initialize();
      expect(provider2.localDevice!.deviceId, equals(id1));
    });

    test('Device Name is configured, persisted, and updated properly', () async {
      final provider = PresenceProvider(mqttService: mockMqtt);
      activeProvider = provider;
      await provider.initialize();

      // Default name check
      expect(provider.localDevice!.displayName.isNotEmpty, isTrue);

      // Update name
      await provider.setDeviceName('Custom Laptop');
      expect(provider.localDevice!.displayName, equals('Custom Laptop'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(PresenceProvider.prefKeyDeviceName), equals('Custom Laptop'));
    });

    test('Remote peer discovery adds device to onlineDevices', () async {
      final provider = PresenceProvider(mqttService: mockMqtt);
      activeProvider = provider;
      await provider.initialize();

      expect(provider.onlineDevices, isEmpty);

      // Simulate remote device presence received
      final remoteDevice = Device(
        deviceId: 'mc_remote_android_999',
        displayName: 'Android Phone',
        platform: 'android',
      );

      mockMqtt.onDevicePresenceReceived?.call(remoteDevice);

      expect(provider.onlineDevices.length, equals(1));
      expect(provider.onlineDevices.first.deviceId, equals('mc_remote_android_999'));
      expect(provider.onlineDevices.first.displayName, equals('Android Phone'));
      expect(provider.onlineDevices.first.platform, equals('android'));
    });

    test('Self-device filtering ensures own device is NEVER in onlineDevices', () async {
      final provider = PresenceProvider(mqttService: mockMqtt);
      activeProvider = provider;
      await provider.initialize();

      final selfId = provider.localDevice!.deviceId;

      // Simulate receiving self presence
      final selfAsRemote = Device(
        deviceId: selfId,
        displayName: 'Self Device',
        platform: 'linux',
      );

      mockMqtt.onDevicePresenceReceived?.call(selfAsRemote);

      // Must be ignored!
      expect(provider.onlineDevices, isEmpty);
    });

    test('Offline notice removes peer from onlineDevices', () async {
      final provider = PresenceProvider(mqttService: mockMqtt);
      activeProvider = provider;
      await provider.initialize();

      final remoteDevice = Device(
        deviceId: 'mc_remote_device_555',
        displayName: 'Remote Phone',
        platform: 'android',
      );

      mockMqtt.onDevicePresenceReceived?.call(remoteDevice);
      expect(provider.onlineDevices.length, equals(1));

      // Simulate offline signal
      mockMqtt.onDeviceOfflineReceived?.call('mc_remote_device_555');
      expect(provider.onlineDevices, isEmpty);
    });

    test('Multiple remote peers are discovered and listed', () async {
      final provider = PresenceProvider(mqttService: mockMqtt);
      activeProvider = provider;
      await provider.initialize();

      final peer1 = Device(
        deviceId: 'mc_peer_1',
        displayName: 'Device Alpha',
        platform: 'linux',
      );
      final peer2 = Device(
        deviceId: 'mc_peer_2',
        displayName: 'Device Beta',
        platform: 'android',
      );

      mockMqtt.onDevicePresenceReceived?.call(peer1);
      mockMqtt.onDevicePresenceReceived?.call(peer2);

      expect(provider.onlineDevices.length, equals(2));
      expect(provider.onlineDevices.map((d) => d.displayName).toList(),
          containsAll(['Device Alpha', 'Device Beta']));
    });
  });
}
