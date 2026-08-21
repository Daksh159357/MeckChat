import 'package:flutter/foundation.dart';
import '../models/message.dart';

class ChatProvider with ChangeNotifier {
  final Map<String, List<ChatMessage>> _conversations = {};

  List<ChatMessage> getMessages(String peerDeviceId) {
    return _conversations[peerDeviceId] ?? [];
  }

  void sendMessage({
    required String recipientDeviceId,
    required String senderDeviceId,
    required String content,
  }) {
    final msg = ChatMessage(
      messageId: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderDeviceId: senderDeviceId,
      recipientDeviceId: recipientDeviceId,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    if (!_conversations.containsKey(recipientDeviceId)) {
      _conversations[recipientDeviceId] = [];
    }
    _conversations[recipientDeviceId]!.add(msg);
    notifyListeners();

    // Simulate async WireGuard P2P delivery confirmation
    Future.delayed(const Duration(milliseconds: 800), () {
      final list = _conversations[recipientDeviceId];
      if (list != null && list.isNotEmpty) {
        final idx = list.indexWhere((m) => m.messageId == msg.messageId);
        if (idx != -1) {
          list[idx] = ChatMessage(
            messageId: msg.messageId,
            senderDeviceId: msg.senderDeviceId,
            recipientDeviceId: msg.recipientDeviceId,
            content: msg.content,
            timestamp: msg.timestamp,
            status: MessageStatus.delivered,
          );
          notifyListeners();
        }
      }
    });
  }
}
