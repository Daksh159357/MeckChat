import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../providers/presence_provider.dart';
import '../../services/chat_db_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final Map<String, String> _lastMessages = {};

  @override
  void initState() {
    super.initState();
    _loadLastMessages();
  }

  Future<void> _loadLastMessages() async {
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    for (final peer in presence.pairedDevices) {
      final lastMsg = await ChatDbService().getLastMessage(peer.deviceId);
      if (lastMsg != null) {
        if (mounted) {
          setState(() {
            _lastMessages[peer.deviceId] = lastMsg.content;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presence = Provider.of<PresenceProvider>(context);
    final pairedList = presence.pairedDevices;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
      ),
      body: pairedList.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 64,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No chats yet.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Pair a device from Devices to start chatting over WireGuard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              itemCount: pairedList.length,
              itemBuilder: (context, index) {
                final peer = pairedList[index];
                final isOnline = presence.onlineDevices.any((d) => d.deviceId == peer.deviceId);
                final isWgConnected = peer.wireGuardStatus == WireGuardTunnelState.connected;
                final lastMsgSnippet = _lastMessages[peer.deviceId] ?? 'No messages yet';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isWgConnected
                          ? Colors.green
                          : (isOnline ? Colors.blue : Colors.grey.shade800),
                      child: Icon(
                        _getPlatformIcon(peer.platform),
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          isWgConnected ? '🟢 ' : (isOnline ? '🔵 ' : '⚪ '),
                          style: const TextStyle(fontSize: 10),
                        ),
                        Text(
                          peer.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isWgConnected
                                ? Colors.green.shade900
                                : (isOnline ? Colors.blue.shade900 : Colors.grey.shade800),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isWgConnected
                                ? 'WireGuard Connected'
                                : (isOnline ? 'HiveMQ Online' : 'Offline'),
                            style: TextStyle(
                              fontSize: 10,
                              color: isWgConnected
                                  ? Colors.greenAccent
                                  : (isOnline ? Colors.cyanAccent : Colors.grey),
                            ),
                          ),
                        )
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        lastMsgSnippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(device: peer),
                        ),
                      ).then((_) => _loadLastMessages());
                    },
                  ),
                );
              },
            ),
    );
  }

  IconData _getPlatformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows;
      case 'android':
        return Icons.phone_android;
      case 'linux':
        return Icons.terminal;
      case 'macos':
        return Icons.laptop_mac;
      case 'ios':
        return Icons.phone_iphone;
      default:
        return Icons.devices;
    }
  }
}
