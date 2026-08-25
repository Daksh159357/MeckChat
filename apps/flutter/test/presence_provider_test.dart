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

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PresenceProvider Tests', () {
    test('Device ID is generated with mc_ prefix and persisted across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs1 = await SharedPreferences.getInstance();
      final mock1 = MockMqttService();
      final provider1 = PresenceProvider(mqttService: mock1, prefs: prefs1, autoStartTimer: false);
      await provider1.initialize();

      expect(provider1.localDevice, isNotNull);
      final id1 = provider1.localDevice!.deviceId;
      expect(id1.startsWith('mc_'), isTrue);
      expect(id1.length, greaterThan(10));
      provider1.dispose();

      // Re-initialize with same storage
      final mock2 = MockMqttService();
      final provider2 = PresenceProvider(mqttService: mock2, prefs: prefs1, autoStartTimer: false);
      await provider2.initialize();
      expect(provider2.localDevice!.deviceId, equals(id1));
      provider2.dispose();
    });

    test('Device Name is configured, persisted, and updated properly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mock = MockMqttService();
      final provider = PresenceProvider(mqttService: mock, prefs: prefs, autoStartTimer: false);
      await provider.initialize();

      // Default name check
      expect(provider.localDevice!.displayName.isNotEmpty, isTrue);

      // Update name
      await provider.setDeviceName('Custom Laptop');
      expect(provider.localDevice!.displayName, equals('Custom Laptop'));
      expect(prefs.getString(PresenceProvider.prefKeyDeviceName), equals('Custom Laptop'));
      provider.dispose();
    });

    test('Remote peer discovery adds device to onlineDevices', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mock = MockMqttService();
      final provider = PresenceProvider(mqttService: mock, prefs: prefs, autoStartTimer: false);
      await provider.initialize();

      expect(provider.onlineDevices, isEmpty);

      // Simulate remote device presence received
      final remoteDevice = Device(
        deviceId: 'mc_remote_android_999',
        displayName: 'Android Phone',
        platform: 'android',
      );

      mock.onDevicePresenceReceived?.call(remoteDevice);

      expect(provider.onlineDevices.length, equals(1));
      expect(provider.onlineDevices.first.deviceId, equals('mc_remote_android_999'));
      expect(provider.onlineDevices.first.displayName, equals('Android Phone'));
      expect(provider.onlineDevices.first.platform, equals('android'));
      provider.dispose();
    });

    test('Self-device filtering ensures own device is NEVER in onlineDevices', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mock = MockMqttService();
      final provider = PresenceProvider(mqttService: mock, prefs: prefs, autoStartTimer: false);
      await provider.initialize();

      final selfId = provider.localDevice!.deviceId;

      // Simulate receiving self presence
      final selfAsRemote = Device(
        deviceId: selfId,
        displayName: 'Self Device',
        platform: 'linux',
      );

      mock.onDevicePresenceReceived?.call(selfAsRemote);

      // Must be ignored!
      expect(provider.onlineDevices, isEmpty);
      provider.dispose();
    });

    test('Offline notice removes peer from onlineDevices', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mock = MockMqttService();
      final provider = PresenceProvider(mqttService: mock, prefs: prefs, autoStartTimer: false);
      await provider.initialize();

      final remoteDevice = Device(
        deviceId: 'mc_remote_device_555',
        displayName: 'Remote Phone',
        platform: 'android',
      );

      mock.onDevicePresenceReceived?.call(remoteDevice);
      expect(provider.onlineDevices.length, equals(1));

      // Simulate offline signal
      mock.onDeviceOfflineReceived?.call('mc_remote_device_555');
      expect(provider.onlineDevices, isEmpty);
      provider.dispose();
    });

    test('Multiple remote peers are discovered and listed', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mock = MockMqttService();
      final provider = PresenceProvider(mqttService: mock, prefs: prefs, autoStartTimer: false);
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

      mock.onDevicePresenceReceived?.call(peer1);
      mock.onDevicePresenceReceived?.call(peer2);

      expect(provider.onlineDevices.length, equals(2));
      expect(provider.onlineDevices.map((d) => d.displayName).toList(),
          containsAll(['Device Alpha', 'Device Beta']));
      provider.dispose();
    });
  });
}
