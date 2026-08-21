import 'package:flutter/material.dart';
import '../../models/device.dart';

class CallScreen extends StatefulWidget {
  final MeckDevice peerDevice;
  final bool isVideo;

  const CallScreen({
    super.key,
    required this.peerDevice,
    required this.isVideo,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'WebRTC P2P ${widget.isVideo ? "Video" : "Voice"} Call',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.blueAccent.shade700,
                  child: Text(
                    widget.peerDevice.displayName[0],
                    style: const TextStyle(fontSize: 36, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.peerDevice.displayName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tunnel IP: ${widget.peerDevice.virtualIp} • WebRTC Encrypted',
                  style: const TextStyle(color: Colors.greenAccent, fontSize: 13),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FloatingActionButton(
                  heroTag: 'mute_btn',
                  onPressed: () => setState(() => _isMuted = !_isMuted),
                  backgroundColor: _isMuted ? Colors.amber : Colors.grey.shade800,
                  child: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                ),
                FloatingActionButton(
                  heroTag: 'hangup_btn',
                  onPressed: () => Navigator.pop(context),
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.call_end),
                ),
                if (widget.isVideo)
                  FloatingActionButton(
                    heroTag: 'camera_btn',
                    onPressed: () => setState(() => _isCameraOff = !_isCameraOff),
                    backgroundColor: _isCameraOff ? Colors.amber : Colors.grey.shade800,
                    child: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
