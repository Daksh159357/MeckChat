import 'package:flutter_test/flutter_test.dart';
import 'package:meckchat/models/device.dart';
import 'package:meckchat/models/message.dart';
import 'package:meckchat/providers/presence_provider.dart';
import 'package:meckchat/services/meckchat_core_service.dart';

void main() {
  group('MeckChat Phase 3 Bug Fix Unit Tests (v0.1.4)', () {
    test('TEST 1: Fresh installation starts with ZERO remote fake devices', () {
      final presence = PresenceProvider();
      expect(presence.onlineDevices.isEmpty, isTrue);
      expect(presence.onlineDevices.length, equals(0));
    });

    test('TEST 2: Device Name Input Validation Rules', () {
      // Empty / Null
      expect(MeckChatCoreService.validateDeviceName(null), isNotNull);
      expect(MeckChatCoreService.validateDeviceName(''), isNotNull);
      expect(MeckChatCoreService.validateDeviceName('   '), isNotNull);

      // Exceeds 40 chars
      final longName = 'A' * 41;
      expect(MeckChatCoreService.validateDeviceName(longName), isNotNull);

      // Control characters
      expect(MeckChatCoreService.validateDeviceName('Bad\x07Name'), isNotNull);

      // Valid names
      expect(MeckChatCoreService.validateDeviceName('My Linux Laptop'), isNull);
      expect(MeckChatCoreService.validateDeviceName('  Daksh-Phone  '), isNull);
    });

    test('TEST 3: Local device identity is NEVER displayed as a remote peer (Self-Device Filtering)', () {
      final presence = PresenceProvider();
      final local = LocalDevice(
        deviceId: 'dev_local_123',
        displayName: 'My Linux Laptop',
        platform: 'Linux',
        wireGuardPublicKey: 'pub_local_wg',
        wireGuardPrivateKey: 'priv_local_wg',
        virtualIp: '10.77.0.2',
      );
      presence.setLocalIdentity(local);

      // Simulate receiving MQTT presence message for local device ID
      presence.handleIncomingPresence({
        'type': 'presence_online',
        'device_id': 'dev_local_123',
        'display_name': 'My Linux Laptop',
        'platform': 'Linux',
        'wireguard_public_key': 'pub_local_wg',
        'virtual_ip': '10.77.0.2',
      });

      // Assert local device is filtered out from remote online devices list
      expect(presence.onlineDevices.isEmpty, isTrue);
    });

    test('TEST 4: Remote devices are added ONLY from valid incoming MQTT presence messages', () {
      final presence = PresenceProvider();
      final local = LocalDevice(
        deviceId: 'dev_local_123',
        displayName: 'My Linux Laptop',
        platform: 'Linux',
        wireGuardPublicKey: 'pub_local',
        wireGuardPrivateKey: 'priv_local',
        virtualIp: '10.77.0.2',
      );
      presence.setLocalIdentity(local);

      // Simulate receiving remote presence from Android device
      presence.handleIncomingPresence({
        'type': 'presence_online',
        'device_id': 'dev_remote_android_456',
        'display_name': 'My Android Phone',
        'platform': 'Android',
        'wireguard_public_key': 'pub_remote_android',
        'virtual_ip': '10.77.0.3',
      });

      expect(presence.onlineDevices.length, equals(1));
      expect(presence.onlineDevices.first.displayName, equals('My Android Phone'));
      expect(presence.onlineDevices.first.platform, equals('Android'));
      expect(presence.onlineDevices.first.wireGuardStatus, equals(WireGuardTunnelState.notConfigured));
    });

    test('TEST 5: Offline presence removes remote device from online peer list', () {
      final presence = PresenceProvider();
      final local = LocalDevice(
        deviceId: 'dev_local_123',
        displayName: 'My Linux Laptop',
        platform: 'Linux',
        wireGuardPublicKey: 'pub_local',
        wireGuardPrivateKey: 'priv_local',
        virtualIp: '10.77.0.2',
      );
      presence.setLocalIdentity(local);

      presence.handleIncomingPresence({
        'type': 'presence_online',
        'device_id': 'dev_remote_789',
        'display_name': 'My Windows PC',
        'platform': 'Windows',
      });
      expect(presence.onlineDevices.length, equals(1));

      // Receive offline presence message
      presence.handleIncomingPresence({
        'type': 'presence_offline',
        'device_id': 'dev_remote_789',
      });
      expect(presence.onlineDevices.isEmpty, isTrue);
    });

    test('TEST 6: WireGuard Private Key is NEVER serialized in JSON signaling or leaked', () {
      final local = LocalDevice(
        deviceId: 'dev_sec_999',
        displayName: 'Secure Device',
        platform: 'Linux',
        wireGuardPublicKey: 'pub_key_public_123',
        wireGuardPrivateKey: 'priv_key_TOP_SECRET_456',
        virtualIp: '10.77.0.2',
      );

      expect(local.assertPrivateKeySafety(), isTrue);
      final json = local.toSignalingJson();
      expect(json.containsKey('wireguard_private_key'), isFalse);
      expect(json.toString().contains('priv_key_TOP_SECRET_456'), isFalse);
    });

    test('TEST 7: WireGuard connection status is distinct from HiveMQ presence status', () {
      final peer = PeerDevice(
        deviceId: 'peer_1',
        displayName: 'Peer A',
        platform: 'Android',
        wireGuardPublicKey: 'pub_1',
        virtualIp: '10.77.0.3',
        isOnline: true,
        wireGuardStatus: WireGuardTunnelState.notConfigured,
      );

      expect(peer.isOnline, isTrue);
      expect(peer.wireGuardStatus, equals(WireGuardTunnelState.notConfigured));
      expect(peer.wireGuardStatus.label, equals('Not Configured'));
    });
  });

  group('MeckChat Message Model Tests', () {
    test('ChatMessage creation and status transitions', () {
      final msg = ChatMessage(
        messageId: 'msg_1',
        senderDeviceId: 'devA',
        recipientDeviceId: 'devB',
        content: 'WireGuard E2E Encrypted Chat',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1724242920000),
        status: MessageStatus.sent,
      );

      expect(msg.content, equals('WireGuard E2E Encrypted Chat'));
      expect(msg.status, equals(MessageStatus.sent));
    });
  });
}
