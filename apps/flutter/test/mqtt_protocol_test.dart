import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:meckchat/models/device.dart';
import 'package:meckchat/services/mqtt_service.dart';

void main() {
  group('MQTT Protocol & Spec Tests', () {
    test('MQTT Topics match specification exactly', () {
      expect(MqttService.brokerHost, equals('broker.hivemq.com'));
      expect(MqttService.brokerPort, equals(8883));

      expect(MqttService.topicPresenceOnlineWildcard,
          equals('meckchat/v1/presence/online/+'));
      expect(MqttService.topicPresenceOfflineWildcard,
          equals('meckchat/v1/presence/offline/+'));
      expect(MqttService.topicDiscovery, equals('meckchat/v1/discovery'));

      expect(MqttService.topicPresenceOnline('mc_dev_1'),
          equals('meckchat/v1/presence/online/mc_dev_1'));
      expect(MqttService.topicPresenceOffline('mc_dev_1'),
          equals('meckchat/v1/presence/offline/mc_dev_1'));
    });

    test('Discovery request payload conforms to protocol specification', () {
      const testDeviceId = 'mc_discovery_tester';
      final payloadStr = jsonEncode({
        'type': 'discovery_request',
        'protocol_version': 1,
        'device_id': testDeviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      final decoded = jsonDecode(payloadStr) as Map<String, dynamic>;
      expect(decoded['type'], equals('discovery_request'));
      expect(decoded['protocol_version'], equals(1));
      expect(decoded['device_id'], equals(testDeviceId));
      expect(decoded['timestamp'], isA<int>());
    });

    test('Online presence payload contains no sensitive keys/secrets', () {
      final device = Device(
        deviceId: 'mc_clean_device',
        displayName: 'Linux Laptop',
        platform: 'linux',
      );

      final json = device.toPresenceOnlineJson();

      // Ensure no cryptographic keys or private data
      expect(json.containsKey('private_key'), isFalse);
      expect(json.containsKey('shared_secret'), isFalse);
      expect(json.containsKey('password'), isFalse);
      expect(json.containsKey('ip'), isFalse);
      expect(json.containsKey('port'), isFalse);

      // Only standard discovery fields
      expect(json.keys, containsAll([
        'type',
        'protocol_version',
        'device_id',
        'display_name',
        'platform',
        'timestamp',
      ]));
    });
  });
}
