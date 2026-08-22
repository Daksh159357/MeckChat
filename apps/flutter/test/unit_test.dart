import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meckchat/models/device.dart';
import 'package:meckchat/models/message.dart';
import 'package:meckchat/providers/presence_provider.dart';
import 'package:meckchat/services/meckchat_core_service.dart';
import 'package:meckchat/services/mqtt_service.dart';
import 'package:meckchat/services/p2p_chat_service.dart';
import 'package:meckchat/services/pairing_service.dart';
import 'package:meckchat/services/paired_devices_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  group('MeckChat Phase 5 Real WireGuard & Security Unit Tests (v0.1.4)', () {
    test('TEST 1: Fresh installation starts with ZERO remote fake devices', () {
      final presence = PresenceProvider();
      expect(presence.onlineDevices.isEmpty, isTrue);
      expect(presence.onlineDevices.length, equals(0));
    });

    test('TEST 2: Device Name Input Validation Rules', () {
      expect(MeckChatCoreService.validateDeviceName(null), isNotNull);
      expect(MeckChatCoreService.validateDeviceName(''), isNotNull);
      expect(MeckChatCoreService.validateDeviceName('   '), isNotNull);
      expect(MeckChatCoreService.validateDeviceName('A' * 41), isNotNull);
      expect(MeckChatCoreService.validateDeviceName('Bad\x07Name'), isNotNull);

      expect(MeckChatCoreService.validateDeviceName('My Linux Laptop'), isNull);
      expect(MeckChatCoreService.validateDeviceName('  My Phone  '), isNull);
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

      presence.handleIncomingPresence({
        'type': 'presence_online',
        'device_id': 'dev_local_123',
        'display_name': 'My Linux Laptop',
        'platform': 'Linux',
        'wireguard_public_key': 'pub_local_wg',
        'virtual_ip': '10.77.0.2',
      });

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
    });

    test('TEST 5: WireGuard Private Key is NEVER serialized in JSON signaling or leaked', () {
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

    test('TEST 6: Argon2id Security Verification Suite (ACCEPT / REJECT Rules)', () {
      const secret = 'MECKCHAT_PAIRING_SECRET_123';
      const senderId = 'dev_linux_123';
      const receiverId = 'dev_android_456';
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final token = PairingService.deriveAuthToken(
        sharedSecret: secret,
        senderDeviceId: senderId,
        receiverDeviceId: receiverId,
        timestamp: timestamp,
      );

      // CASE A: Correct secret & valid proof -> ACCEPT
      final isValid = PairingService.verifySharedSecret(
        sharedSecret: secret,
        salt: token['salt']!,
        senderDeviceId: senderId,
        receiverDeviceId: receiverId,
        timestamp: timestamp,
        incomingAuthTag: token['auth_tag']!,
      );
      expect(isValid, isTrue);

      // CASE B: Wrong secret -> REJECT
      final isWrongSecret = PairingService.verifySharedSecret(
        sharedSecret: 'WRONG_SECRET',
        salt: token['salt']!,
        senderDeviceId: senderId,
        receiverDeviceId: receiverId,
        timestamp: timestamp,
        incomingAuthTag: token['auth_tag']!,
      );
      expect(isWrongSecret, isFalse);

      // CASE C: Modified proof / auth tag -> REJECT
      final isModifiedProof = PairingService.verifySharedSecret(
        sharedSecret: secret,
        salt: token['salt']!,
        senderDeviceId: senderId,
        receiverDeviceId: receiverId,
        timestamp: timestamp,
        incomingAuthTag: '${token['auth_tag']!}tampered',
      );
      expect(isModifiedProof, isFalse);

      // CASE D: Modified sender device ID -> REJECT
      final isModifiedDeviceId = PairingService.verifySharedSecret(
        sharedSecret: secret,
        salt: token['salt']!,
        senderDeviceId: 'ATTACKER_DEVICE_ID',
        receiverDeviceId: receiverId,
        timestamp: timestamp,
        incomingAuthTag: token['auth_tag']!,
      );
      expect(isModifiedDeviceId, isFalse);
    });

    test('TEST 7: MQTT Data-Plane Isolation (Assert Zero Chat / File Data in MQTT)', () {
      final validSignal = {
        'type': 'PAIR_REQUEST',
        'sender_device_id': 'devA',
        'receiver_device_id': 'devB',
        'wireguard_public_key': 'pub_123',
      };
      expect(MqttService.assertNoChatDataInMqtt(validSignal), isTrue);

      final invalidSignalWithChat = {
        'type': 'PAIR_REQUEST',
        'chat_content': 'Secret chat payload over MQTT',
      };
      expect(MqttService.assertNoChatDataInMqtt(invalidSignalWithChat), isFalse);
    });

    test('TEST 8: Chat Connection Guard Enforcement', () {
      final p2pService = P2PChatService();

      // Guard check when disconnected -> returns false
      final canSendDisconnected = p2pService.canSendMessage(
        isPaired: true,
        wireGuardStatus: WireGuardTunnelState.disconnected,
        isReachable: false,
      );
      expect(canSendDisconnected, isFalse);

      // Guard check when connected -> returns true
      final canSendConnected = p2pService.canSendMessage(
        isPaired: true,
        wireGuardStatus: WireGuardTunnelState.connected,
        isReachable: true,
      );
      expect(canSendConnected, isTrue);
    });

    test('TEST 9: Paired Devices Local Storage Persistence', () async {
      final peer = PeerDevice(
        deviceId: 'dev_paired_999',
        displayName: 'Paired Phone',
        platform: 'Android',
        wireGuardPublicKey: 'pub_paired_wg',
        virtualIp: '10.77.0.5',
        isPaired: true,
      );

      await PairedDevicesService().savePairedDevice(peer);
      expect(PairedDevicesService().isPaired('dev_paired_999'), isTrue);

      final retrieved = PairedDevicesService().getPairedDevice('dev_paired_999');
      expect(retrieved, isNotNull);
      expect(retrieved!.displayName, equals('Paired Phone'));
    });
  });

  group('MeckChat Message Model & Status Tests', () {
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

      final json = msg.toJson();
      expect(json['message_id'], equals('msg_1'));
      expect(json['status'], equals('SENT'));

      final decoded = ChatMessage.fromJson(json);
      expect(decoded.messageId, equals('msg_1'));
      expect(decoded.status, equals(MessageStatus.sent));
    });
  });
}
