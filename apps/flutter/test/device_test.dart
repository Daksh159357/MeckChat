import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:meckchat/models/device.dart';

void main() {
  group('Device Model & Presence Payload Tests', () {
    test('Device serialization for presence_online generates valid JSON payload', () {
      final device = Device(
        deviceId: 'mc_test_device_123',
        displayName: 'Linux Laptop',
        platform: 'linux',
      );

      final json = device.toPresenceOnlineJson();

      expect(json['type'], equals('presence_online'));
      expect(json['protocol_version'], equals(1));
      expect(json['device_id'], equals('mc_test_device_123'));
      expect(json['display_name'], equals('Linux Laptop'));
      expect(json['platform'], equals('linux'));
      expect(json['timestamp'], isA<int>());
      expect(json['timestamp'], greaterThan(0));
    });

    test('Device serialization for presence_offline generates valid JSON payload', () {
      final device = Device(
        deviceId: 'mc_test_device_123',
        displayName: 'Linux Laptop',
        platform: 'linux',
      );

      final json = device.toPresenceOfflineJson();

      expect(json['type'], equals('presence_offline'));
      expect(json['device_id'], equals('mc_test_device_123'));
    });

    test('Device deserialization from valid MQTT presence_online JSON map', () {
      final jsonMap = {
        'type': 'presence_online',
        'protocol_version': 1,
        'device_id': 'mc_android_phone_456',
        'display_name': 'Android Phone',
        'platform': 'android',
        'timestamp': 1724540000,
      };

      final device = Device.fromPresenceJson(jsonMap);

      expect(device, isNotNull);
      expect(device!.deviceId, equals('mc_android_phone_456'));
      expect(device.displayName, equals('Android Phone'));
      expect(device.platform, equals('android'));
      expect(device.isOnline, isTrue);
      expect(device.lastSeen.millisecondsSinceEpoch, equals(1724540000 * 1000));
    });

    test('Device deserialization from valid MQTT presence payload string', () {
      final payload = jsonEncode({
        'type': 'presence_online',
        'protocol_version': 1,
        'device_id': 'mc_linux_laptop_789',
        'display_name': 'Linux Laptop',
        'platform': 'linux',
        'timestamp': 1724541234,
      });

      final device = Device.fromPresencePayload(payload);

      expect(device, isNotNull);
      expect(device!.deviceId, equals('mc_linux_laptop_789'));
      expect(device.displayName, equals('Linux Laptop'));
      expect(device.platform, equals('linux'));
      expect(device.isOnline, isTrue);
    });

    test('Device deserialization fails safely on invalid or missing device_id', () {
      expect(Device.fromPresenceJson({}), isNull);
      expect(Device.fromPresenceJson({'device_id': ''}), isNull);
      expect(Device.fromPresencePayload('invalid_json'), isNull);
      expect(Device.fromPresencePayload(''), isNull);
    });
  });
}
