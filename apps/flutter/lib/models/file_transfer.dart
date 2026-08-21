enum FileTransferStatus {
  initializing,
  transferring,
  paused,
  verifying,
  completed,
  failed,
}

class FileTransferItem {
  final String fileId;
  final String filename;
  final int totalBytes;
  final int transferredBytes;
  final String sha256Hash;
  final FileTransferStatus status;
  final bool isOutgoing;
  final String peerDeviceId;

  FileTransferItem({
    required this.fileId,
    required this.filename,
    required this.totalBytes,
    required this.transferredBytes,
    required this.sha256Hash,
    required this.status,
    required this.isOutgoing,
    required this.peerDeviceId,
  });

  double get progress => totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;

  FileTransferItem copyWith({
    int? transferredBytes,
    FileTransferStatus? status,
  }) {
    return FileTransferItem(
      fileId: fileId,
      filename: filename,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      sha256Hash: sha256Hash,
      status: status ?? this.status,
      isOutgoing: isOutgoing,
      peerDeviceId: peerDeviceId,
    );
  }
}
