import 'package:flutter_test/flutter_test.dart';
import 'package:meckchat/models/device.dart';
import 'package:meckchat/models/message.dart';
import 'package:meckchat/models/file_transfer.dart';
import 'package:meckchat/services/meckchat_core_service.dart';

void main() {
  group('MeckChat Device Identity Security Tests', () {
    test('Device identity json serialization does not leak private key', () {
      final device = MeckDevice(
        deviceId: 'dev_test123',
        displayName: 'Test-Device',
        platform: 'Linux',
        wireGuardPublicKey: 'pubkey_abc123',
        virtualIp: '10.77.0.2',
      );

      final json = device.toJson();
      expect(json.containsKey('privateKey'), isFalse);
      expect(json.containsKey('secret'), isFalse);
      expect(json['deviceId'], equals('dev_test123'));
      expect(json['virtualIp'], equals('10.77.0.2'));
    });

    test('MeckChatCoreService asserts secret safety', () async {
      final service = MeckChatCoreService();
      await service.initializeLocalIdentity(name: 'Test-PC', platform: 'Windows');
      expect(service.localIdentity, isNotNull);
      expect(service.assertPrivateKeySafety(), isTrue);
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

      final json = msg.toJson();
      expect(json['status'], equals('sent'));
    });
  });

  group('MeckChat File Transfer Engine Tests', () {
    test('FileTransferItem progress calculation', () {
      final transfer = FileTransferItem(
        fileId: 'file_001',
        filename: 'document.pdf',
        totalBytes: 1048576, // 1 MB
        transferredBytes: 524288, // 512 KB
        sha256Hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        status: FileTransferStatus.transferring,
        isIncoming: false,
      );

      expect(transfer.progress, equals(0.5));
    });
  });
}
