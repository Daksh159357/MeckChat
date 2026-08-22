import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/device.dart';
import '../../providers/presence_provider.dart';
import '../../services/pairing_service.dart';

class PairingScreen extends StatefulWidget {
  final PeerDevice? targetPeer;

  const PairingScreen({super.key, this.targetPeer});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _secretController = TextEditingController();
  PeerDevice? _selectedPeer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedPeer = widget.targetPeer;
  }

  String _buildQrPayload(LocalDevice? localDevice) {
    if (localDevice == null) return '{}';
    return jsonEncode(localDevice.toSignalingJson());
  }

  @override
  Widget build(BuildContext context) {
    final presence = Provider.of<PresenceProvider>(context);
    final localDevice = presence.localDevice;
    final qrData = _buildQrPayload(localDevice);
    final onlinePeers = presence.onlineDevices;

    if (_selectedPeer == null && onlinePeers.isNotEmpty) {
      _selectedPeer = onlinePeers.first;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair Device'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: 'My QR Code'),
            Tab(icon: Icon(Icons.key), text: 'Shared Secret'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 240.0,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Scan to Connect',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contains only public WireGuard key and device metadata.\nPrivate keys and secrets are NEVER in QR codes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shared Secret Pairing (Argon2id KDF)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter identical shared secret on both devices. Secret material is derived using Argon2id and never sent in plaintext over HiveMQ.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 16),
                if (onlinePeers.isNotEmpty) ...[
                  const Text('Select Target Device to Pair:', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPeer?.deviceId,
                    dropdownColor: const Color(0xFF1E293B),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    items: onlinePeers.map((peer) {
                      return DropdownMenuItem<String>(
                        value: peer.deviceId,
                        child: Text(
                          '${peer.displayName} (${peer.platform})',
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedPeer = onlinePeers.firstWhere((p) => p.deviceId == val);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _secretController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Shared Secret (e.g. MECKCHAT123)',
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    final secret = _secretController.text.trim();
                    if (secret.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a shared secret.')),
                      );
                      return;
                    }

                    if (_selectedPeer == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('No target peer selected for pairing.')),
                      );
                      return;
                    }

                    await PairingService().initiatePairing(
                      targetPeer: _selectedPeer!,
                      sharedSecret: secret,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Argon2id pairing request sent to ${_selectedPeer!.displayName} over MQTT!'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Authenticate Pairing'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
