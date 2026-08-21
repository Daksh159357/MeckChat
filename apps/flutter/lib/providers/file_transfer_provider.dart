import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/file_transfer.dart';

class FileTransferProvider with ChangeNotifier {
  final List<FileTransferItem> _transfers = [];

  List<FileTransferItem> get transfers => List.unmodifiable(_transfers);

  void startTransfer({
    required String filename,
    required int totalBytes,
    required String sha256Hash,
    required String peerDeviceId,
    bool isOutgoing = true,
  }) {
    final item = FileTransferItem(
      fileId: 'file_${DateTime.now().millisecondsSinceEpoch}',
      filename: filename,
      totalBytes: totalBytes,
      transferredBytes: 0,
      sha256Hash: sha256Hash,
      status: FileTransferStatus.transferring,
      isOutgoing: isOutgoing,
      peerDeviceId: peerDeviceId,
    );

    _transfers.add(item);
    notifyListeners();

    _simulateChunkedProgress(item.fileId);
  }

  void pauseTransfer(String fileId) {
    final idx = _transfers.indexWhere((t) => t.fileId == fileId);
    if (idx != -1) {
      _transfers[idx] = _transfers[idx].copyWith(status: FileTransferStatus.paused);
      notifyListeners();
    }
  }

  void resumeTransfer(String fileId) {
    final idx = _transfers.indexWhere((t) => t.fileId == fileId);
    if (idx != -1) {
      _transfers[idx] = _transfers[idx].copyWith(status: FileTransferStatus.transferring);
      notifyListeners();
      _simulateChunkedProgress(fileId);
    }
  }

  void _simulateChunkedProgress(String fileId) {
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      final idx = _transfers.indexWhere((t) => t.fileId == fileId);
      if (idx == -1) {
        timer.cancel();
        return;
      }

      final item = _transfers[idx];
      if (item.status != FileTransferStatus.transferring) {
        timer.cancel();
        return;
      }

      final chunkSize = (item.totalBytes * 0.15).round();
      final newTransferred = (item.transferredBytes + chunkSize).clamp(0, item.totalBytes);

      if (newTransferred >= item.totalBytes) {
        _transfers[idx] = item.copyWith(
          transferredBytes: item.totalBytes,
          status: FileTransferStatus.verifying,
        );
        notifyListeners();
        timer.cancel();

        // SHA-256 verification completion
        Future.delayed(const Duration(milliseconds: 500), () {
          final vIdx = _transfers.indexWhere((t) => t.fileId == fileId);
          if (vIdx != -1) {
            _transfers[vIdx] = _transfers[vIdx].copyWith(status: FileTransferStatus.completed);
            notifyListeners();
          }
        });
      } else {
        _transfers[idx] = item.copyWith(transferredBytes: newTransferred);
        notifyListeners();
      }
    });
  }
}
