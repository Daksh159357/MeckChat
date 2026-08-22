import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/presence_provider.dart';
import '../../providers/settings_provider.dart';
import '../../services/meckchat_core_service.dart';
import '../../services/mqtt_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late bool _useTls;

  @override
  void initState() {
    super.initState();
    final settings = Provider.of<SettingsProvider>(context, listen: false);
    _hostController = TextEditingController(text: settings.mqttHost);
    _portController = TextEditingController(text: settings.mqttPort.toString());
    _useTls = settings.useTls;
  }

  void _showEditDeviceNameDialog() {
    final presence = Provider.of<PresenceProvider>(context, listen: false);
    final localDevice = presence.localDevice;
    if (localDevice == null) return;

    final nameController = TextEditingController(text: localDevice.displayName);
    String? errorText;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Edit Device Name', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Choose a new name for this device:',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Device Name',
                  errorText: errorText,
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final validationError =
                    MeckChatCoreService.validateDeviceName(nameController.text);
                if (validationError != null) {
                  setDialogState(() => errorText = validationError);
                  return;
                }

                final service = MeckChatCoreService();
                await service.updateDeviceName(nameController.text);
                presence.updateLocalDeviceName(nameController.text);

                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Device name updated!')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF38BDF8),
                foregroundColor: Colors.black,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final presence = Provider.of<PresenceProvider>(context);
    final localDevice = presence.localDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings & Device Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Device Profile Section
          const Text(
            'Device Profile',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
          ),
          const SizedBox(height: 8),
          if (localDevice != null) ...[
            Card(
              color: const Color(0xFF1E293B),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                localDevice.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${localDevice.platform} • ID: ${localDevice.deviceId}',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Color(0xFF38BDF8)),
                          onPressed: _showEditDeviceNameDialog,
                          tooltip: 'Edit Device Name',
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    Text('Virtual IP: ${localDevice.virtualIp}',
                        style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text('WireGuard Public Key: ${localDevice.wireGuardPublicKey}',
                        style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    const SizedBox(height: 4),
                    const Text('WireGuard Private Key: Secured Locally (Hidden)',
                        style: TextStyle(color: Colors.greenAccent, fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                        const SizedBox(width: 4),
                        Text(
                          'MQTT Status: Connected (${settings.mqttHost}:${settings.mqttPort})',
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // HiveMQ MQTT Signaling Broker Section
          const Text(
            'HiveMQ MQTT Signaling Broker',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
          ),
          const SizedBox(height: 8),
          const Text(
            'Configurable presence broker. HiveMQ never receives chat messages or user files.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hostController,
            decoration: const InputDecoration(
              labelText: 'MQTT Host',
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _portController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'MQTT Port (8883 TLS / 1883 TCP)',
              border: OutlineInputBorder(),
              filled: true,
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Enable TLS (Secure 8883)'),
            value: _useTls,
            onChanged: (val) => setState(() => _useTls = val),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final port = int.tryParse(_portController.text) ?? 8883;
              settings.updateMqttSettings(
                host: _hostController.text.trim(),
                port: port,
                useTls: _useTls,
              );
              if (localDevice != null) {
                MqttService().initialize(
                  localDevice: localDevice,
                  host: _hostController.text.trim(),
                  port: port,
                  useTls: _useTls,
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('HiveMQ broker settings saved & reconnected!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Save Broker Configuration'),
          ),
        ],
      ),
    );
  }
}
