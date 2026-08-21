import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../providers/presence_provider.dart';
import '../chat/chat_screen.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final presence = Provider.of<PresenceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MeckChat — Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => presence.initMockPresence(),
            tooltip: 'Query HiveMQ Presence',
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blueGrey.shade900,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.cyanAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HiveMQ indicates online presence & signaling only. All chat, files & calls travel over WireGuard tunnel.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Online Devices',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: presence.onlineDevices.length,
              itemBuilder: (context, index) {
                final device = presence.onlineDevices[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  color: Colors.grey.shade900,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: device.state == MeckConnectionState.connected
                          ? Colors.green
                          : Colors.grey.shade800,
                      child: Icon(
                        _getPlatformIcon(device.platform),
                        color: Colors.white,
                      ),
                    ),
                    title: Row(
                      children: [
                        const Text(
                          '🟢 ',
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          device.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade900,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'HiveMQ Online',
                            style: TextStyle(fontSize: 10, color: Colors.cyanAccent),
                          ),
                        )
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${device.platform} • Virtual IP: ${device.virtualIp}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        Row(
                          children: [
                            Icon(
                              device.state == MeckConnectionState.connected
                                  ? Icons.lock
                                  : Icons.lock_open,
                              size: 12,
                              color: device.state == MeckConnectionState.connected
                                  ? Colors.greenAccent
                                  : Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              device.state == MeckConnectionState.connected
                                  ? 'WireGuard Connected (${device.virtualIp})'
                                  : 'WireGuard Tunnel: ${device.state.label}',
                              style: TextStyle(
                                color: device.state == MeckConnectionState.connected
                                    ? Colors.greenAccent
                                    : Colors.amber,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        if (device.state != MeckConnectionState.connected) {
                          await presence.connectToDevice(device.deviceId);
                        }
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(device: device),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: device.state == MeckConnectionState.connected
                            ? Colors.green
                            : Colors.blueAccent,
                      ),
                      child: Text(
                        device.state == MeckConnectionState.connected ? 'Chat' : 'Connect',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
