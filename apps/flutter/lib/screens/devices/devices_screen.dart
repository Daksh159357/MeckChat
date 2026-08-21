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
    final localDevice = presence.localDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MeckChat — Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => presence.refreshPresence(),
            tooltip: 'Refresh MQTT Presence',
          )
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner info box
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blueGrey.shade900,
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.cyanAccent),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HiveMQ carries presence & signaling ONLY. All chat, files & call data travel directly through WireGuard.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // THIS DEVICE Card
          if (localDevice != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: Text(
                'THIS DEVICE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.cyanAccent.shade100,
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF38BDF8),
                  child: Icon(
                    _getPlatformIcon(localDevice.platform),
                    color: Colors.black,
                  ),
                ),
                title: Row(
                  children: [
                    Text(
                      localDevice.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade900,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🟢 ', style: TextStyle(fontSize: 8)),
                          Text(
                            'HiveMQ Connected',
                            style: TextStyle(fontSize: 10, color: Colors.greenAccent),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
                subtitle: Text(
                  '${localDevice.platform} • Local Virtual IP: ${localDevice.virtualIp}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          ],

          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'ONLINE DEVICES',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
          ),

          // REMOTE ONLINE DEVICES List / Empty State
          Expanded(
            child: presence.onlineDevices.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.devices_other_outlined,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No devices online.',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start MeckChat on another device to see it here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => presence.refreshPresence(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              foregroundColor: const Color(0xFF38BDF8),
                              side: const BorderSide(color: Color(0xFF38BDF8)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: presence.onlineDevices.length,
                    itemBuilder: (context, index) {
                      final peer = presence.onlineDevices[index];
                      final isConnected =
                          peer.wireGuardStatus == WireGuardTunnelState.connected;

                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        color: Colors.grey.shade900,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isConnected
                                ? Colors.green
                                : Colors.grey.shade800,
                            child: Icon(
                              _getPlatformIcon(peer.platform),
                              color: Colors.white,
                            ),
                          ),
                          title: Row(
                            children: [
                              const Text(
                                '🟢 ',
                                style: TextStyle(fontSize: 10),
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
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade900,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'HiveMQ Online',
                                  style: TextStyle(
                                      fontSize: 10, color: Colors.cyanAccent),
                                ),
                              )
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${peer.platform}${peer.virtualIp.isNotEmpty ? " • IP: ${peer.virtualIp}" : ""}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    isConnected ? Icons.lock : Icons.lock_open,
                                    size: 12,
                                    color:
                                        isConnected ? Colors.greenAccent : Colors.amber,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isConnected
                                        ? 'WireGuard Connected (${peer.virtualIp})'
                                        : 'WireGuard: ${peer.wireGuardStatus.label}',
                                    style: TextStyle(
                                      color: isConnected
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
                              if (peer.wireGuardStatus !=
                                  WireGuardTunnelState.connected) {
                                await presence.connectToDevice(peer.deviceId);
                              }
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(device: peer),
                                  ),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isConnected
                                  ? Colors.green
                                  : Colors.blueAccent,
                            ),
                            child: Text(
                              isConnected ? 'Chat' : 'Connect',
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
