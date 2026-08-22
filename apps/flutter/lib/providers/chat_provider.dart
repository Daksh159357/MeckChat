import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/message.dart';
import '../services/chat_db_service.dart';
import '../services/p2p_chat_service.dart';

class ChatProvider with ChangeNotifier {
  final Map<String, List<ChatMessage>> _conversations = {};

  ChatProvider() {
    _initP2PListener();
  }

  void _initP2PListener() {
    P2PChatService().startListener();
    P2PChatService().onMessageReceived = (ChatMessage msg) {
      _addIncomingMessage(msg);
    };
  }

  List<ChatMessage> getMessages(String peerDeviceId) {
    if (!_conversations.containsKey(peerDeviceId)) {
      loadMessagesFromDb(peerDeviceId);
      return [];
    }
    return _conversations[peerDeviceId] ?? [];
  }

  Future<void> loadMessagesFromDb(String peerDeviceId) async {
    final history = await ChatDbService().getConversation(peerDeviceId);
    _conversations[peerDeviceId] = history;
    notifyListeners();
  }

  Future<void> sendMessage({
    required String recipientDeviceId,
    required String senderDeviceId,
    required String content,
    String recipientVirtualIp = '',
  }) async {
    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final msg = ChatMessage(
      messageId: msgId,
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

    // Send strictly over WireGuard P2P socket transport (NEVER HiveMQ)
    final finalStatus = await P2PChatService().sendMessageOverWireGuard(
      targetVirtualIp: recipientVirtualIp,
      message: msg,
    );

    // Update in local cache
    final list = _conversations[recipientDeviceId];
    if (list != null) {
      final idx = list.indexWhere((m) => m.messageId == msgId);
      if (idx != -1) {
        list[idx] = ChatMessage(
          messageId: msg.messageId,
          senderDeviceId: msg.senderDeviceId,
          recipientDeviceId: msg.recipientDeviceId,
          content: msg.content,
          timestamp: msg.timestamp,
          status: finalStatus,
        );
        notifyListeners();
      }
    }
  }

  void _addIncomingMessage(ChatMessage msg) {
    final peerId = msg.senderDeviceId;
    if (!_conversations.containsKey(peerId)) {
      _conversations[peerId] = [];
    }
    // Deduplication check
    final exists = _conversations[peerId]!.any((m) => m.messageId == msg.messageId);
    if (!exists) {
      _conversations[peerId]!.add(msg);
      notifyListeners();
    }
  }
}
