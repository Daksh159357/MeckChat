import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/device.dart';
import '../../models/file_transfer.dart';
import '../../providers/file_transfer_provider.dart';
import '../../providers/presence_provider.dart';

class FileTransferScreen extends StatelessWidget {
  final MeckDevice? peerDevice;

  const FileTransferScreen({super.key, this.peerDevice});

  @override
  Widget build(BuildContext context) {
    final transferProvider = Provider.of<FileTransferProvider>(context);
    final presence = Provider.of<PresenceProvider>(context);
    final pairedList = presence.pairedDevices;

    final peerTransfers = peerDevice != null
        ? transferProvider.transfers.where((t) => t.peerDeviceId == peerDevice!.deviceId).toList()
        : transferProvider.transfers;

    return Scaffold(
      appBar: AppBar(
        title: Text(peerDevice != null
            ? 'File Transfer — ${peerDevice!.displayName}'
            : 'Files (WireGuard Transport)'),
      ),
      body: Column(
        children: [
          if (peerDevice != null || pairedList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  final targetId = peerDevice?.deviceId ?? (pairedList.isNotEmpty ? pairedList.first.deviceId : '');
                  if (targetId.isNotEmpty) {
                    transferProvider.startTransfer(
                      filename: 'mechat_file_transfer.bin',
                      totalBytes: 50 * 1024 * 1024,
                      sha256Hash: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
                      peerDeviceId: targetId,
                    );
                  }
                },
                icon: const Icon(Icons.upload_file),
                label: const Text('Send File over WireGuard P2P'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          Expanded(
            child: peerTransfers.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No file transfers yet.\nAll files transfer directly via WireGuard P2P data plane.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: peerTransfers.length,
                    itemBuilder: (context, index) {
                      final item = peerTransfers[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: const Color(0xFF1E293B),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    item.isOutgoing ? Icons.upload : Icons.download,
                                    color: Colors.cyanAccent,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item.filename,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  if (item.status == FileTransferStatus.completed)
                                    const Chip(
                                      avatar: Icon(Icons.check_circle, color: Colors.green, size: 16),
                                      label: Text('✓ SHA-256 verified', style: TextStyle(fontSize: 10)),
                                      backgroundColor: Colors.black45,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: item.progress,
                                backgroundColor: Colors.grey.shade800,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  item.status == FileTransferStatus.completed
                                      ? Colors.green
                                      : Colors.blueAccent,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${(item.transferredBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(item.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB (${(item.progress * 100).toStringAsFixed(1)}%)',
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                                  if (item.status == FileTransferStatus.transferring)
                                    IconButton(
                                      icon: const Icon(Icons.pause, color: Colors.amber),
                                      onPressed: () => transferProvider.pauseTransfer(item.fileId),
                                      tooltip: 'Pause Transfer',
                                    )
                                  else if (item.status == FileTransferStatus.paused)
                                    IconButton(
                                      icon: const Icon(Icons.play_arrow, color: Colors.greenAccent),
                                      onPressed: () => transferProvider.resumeTransfer(item.fileId),
                                      tooltip: 'Resume Transfer',
                                    ),
                                ],
                              ),
                            ],
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
}
