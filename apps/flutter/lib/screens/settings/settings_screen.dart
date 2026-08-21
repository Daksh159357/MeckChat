import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings — HiveMQ & WireGuard'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'HiveMQ MQTT Signaling Broker',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('HiveMQ broker settings saved!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              minimumSize: const Size.fromHeight(48),
            ),
            child: const Text('Save Configuration'),
          ),
        ],
      ),
    );
  }
}
