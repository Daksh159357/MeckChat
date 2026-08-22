import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/device.dart';
import '../models/message.dart';
import 'chat_db_service.dart';

typedef OnMessageReceivedCallback = void Function(ChatMessage message);

class P2PChatService {
  static final P2PChatService _instance = P2PChatService._internal();
  factory P2PChatService() => _instance;
  P2PChatService._internal();

  ServerSocket? _serverSocket;
  OnMessageReceivedCallback? onMessageReceived;
  bool _isListening = false;
  static const int p2pPort = 51821;

  /// Starts listening for incoming direct P2P chat messages and health pings over WireGuard tunnel interface
  Future<void> startListener() async {
    if (_isListening) return;
    try {
      _serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, p2pPort);
      _isListening = true;
      debugPrint('P2P WireGuard chat server listening on port $p2pPort');

      _serverSocket!.listen((Socket socket) {
        socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) async {
          try {
            final Map<String, dynamic> json = jsonDecode(line);
            final type = json['type'] as String? ?? '';

            if (type == 'HEALTH_PING') {
              // Respond to P2P WireGuard health ping
              socket.writeln(jsonEncode({
                'type': 'HEALTH_PONG',
                'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
              }));
            } else if (type == 'CHAT_TEXT' || json.containsKey('message_id')) {
              final msg = ChatMessage.fromJson(json).copyWith(status: MessageStatus.delivered);
              await ChatDbService().insertMessage(msg);

              // Respond with P2P delivery ACK over WireGuard
              socket.writeln(jsonEncode({
                'type': 'CHAT_ACK',
                'message_id': msg.messageId,
              }));

              onMessageReceived?.call(msg);
            }
          } catch (e) {
            debugPrint('Error processing incoming P2P frame: $e');
          }
        });
      });
    } catch (e) {
      debugPrint('P2P ServerSocket bind info: $e');
    }
  }

  /// Performs a direct WireGuard socket health check (HEALTH_PING / HEALTH_PONG) over 10.77.x.y:51821
  Future<bool> performWireGuardHealthCheck(String targetVirtualIp) async {
    if (targetVirtualIp.isEmpty) return false;
    try {
      final socket = await Socket.connect(targetVirtualIp, p2pPort, timeout: const Duration(seconds: 2));
      final payload = {
        'type': 'HEALTH_PING',
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };

      socket.writeln(jsonEncode(payload));
      await socket.flush();

      final completer = Completer<bool>();
      socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        try {
          final json = jsonDecode(line);
          if (json['type'] == 'HEALTH_PONG') {
            completer.complete(true);
          }
        } catch (_) {}
      });

      final isHealthy = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );

      socket.destroy();
      return isHealthy;
    } catch (e) {
      debugPrint('WireGuard P2P health check failed for $targetVirtualIp: $e');
      return false;
    }
  }

  /// Enforces Chat Connection Guard: Message may ONLY be sent when peer is paired and WireGuard is CONNECTED
  bool canSendMessage({
    required bool isPaired,
    required WireGuardTunnelState wireGuardStatus,
    required bool isReachable,
  }) {
    return isPaired && wireGuardStatus == WireGuardTunnelState.connected && isReachable;
  }

  /// Sends a text message directly over the WireGuard P2P socket transport (0% MQTT)
  Future<MessageStatus> sendMessageOverWireGuard({
    required String targetVirtualIp,
    required ChatMessage message,
    bool isPaired = true,
    WireGuardTunnelState wireGuardStatus = WireGuardTunnelState.connected,
  }) async {
    // Check Chat Connection Guard
    if (targetVirtualIp.isEmpty || wireGuardStatus != WireGuardTunnelState.connected) {
      debugPrint('Chat Connection Guard: WireGuard tunnel not connected. Saving message as PENDING.');
      await ChatDbService().insertMessage(message.copyWith(status: MessageStatus.pending));
      return MessageStatus.pending;
    }

    // First save to local SQLite database as PENDING or SENT
    await ChatDbService().insertMessage(message.copyWith(status: MessageStatus.sent));

    try {
      final socket = await Socket.connect(targetVirtualIp, p2pPort, timeout: const Duration(seconds: 3));
      final payload = message.toJson();
      payload['type'] = 'CHAT_TEXT';

      socket.writeln(jsonEncode(payload));
      await socket.flush();

      // Await delivery ACK over WireGuard
      final completer = Completer<MessageStatus>();
      socket.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
        try {
          final json = jsonDecode(line);
          if (json['type'] == 'CHAT_ACK' && json['message_id'] == message.messageId) {
            completer.complete(MessageStatus.delivered);
          }
        } catch (_) {}
      });

      final finalStatus = await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () => MessageStatus.sent,
      );

      socket.destroy();
      await ChatDbService().updateStatus(message.messageId, finalStatus);
      return finalStatus;
    } catch (e) {
      debugPrint('Direct WireGuard P2P socket unreachable ($targetVirtualIp): $e');
      await ChatDbService().updateStatus(message.messageId, MessageStatus.pending);
      return MessageStatus.pending;
    }
  }

  /// Flushes pending offline messages to peer once WireGuard tunnel is established
  Future<void> flushPendingMessages(String peerDeviceId, String peerVirtualIp) async {
    if (peerVirtualIp.isEmpty) return;
    final pending = await ChatDbService().getPendingMessages(peerDeviceId);
    for (final msg in pending) {
      final status = await sendMessageOverWireGuard(
        targetVirtualIp: peerVirtualIp,
        message: msg,
        isPaired: true,
        wireGuardStatus: WireGuardTunnelState.connected,
      );
      if (status == MessageStatus.delivered) {
        await ChatDbService().updateStatus(msg.messageId, MessageStatus.delivered);
      }
    }
  }

  void stopListener() {
    _serverSocket?.close();
    _serverSocket = null;
    _isListening = false;
  }
}
