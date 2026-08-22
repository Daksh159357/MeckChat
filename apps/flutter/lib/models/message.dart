enum MessageStatus {
  pending,
  sent,
  delivered,
  read,
  failed,
}

class ChatMessage {
  final String messageId;
  final String senderDeviceId;
  final String recipientDeviceId;
  final String content;
  final DateTime timestamp;
  final MessageStatus status;

  ChatMessage({
    required this.messageId,
    required this.senderDeviceId,
    required this.recipientDeviceId,
    required this.content,
    required this.timestamp,
    this.status = MessageStatus.sent,
  });

  ChatMessage copyWith({
    String? messageId,
    String? senderDeviceId,
    String? recipientDeviceId,
    String? content,
    DateTime? timestamp,
    MessageStatus? status,
  }) {
    return ChatMessage(
      messageId: messageId ?? this.messageId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      recipientDeviceId: recipientDeviceId ?? this.recipientDeviceId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      messageId: json['message_id'],
      senderDeviceId: json['sender_device_id'],
      recipientDeviceId: json['recipient_device_id'],
      content: json['content'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] * 1000),
      status: MessageStatus.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['status'] ?? 'SENT'),
        orElse: () => MessageStatus.sent,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'message_id': messageId,
        'sender_device_id': senderDeviceId,
        'recipient_device_id': recipientDeviceId,
        'content': content,
        'timestamp': (timestamp.millisecondsSinceEpoch / 1000).round(),
        'status': status.name.toUpperCase(),
      };
}
