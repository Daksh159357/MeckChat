import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device.dart';

class PairedDevicesService {
  static const String _key = 'meckchat_paired_devices';

  static final PairedDevicesService _instance = PairedDevicesService._internal();
  factory PairedDevicesService() => _instance;
  PairedDevicesService._internal();

  final Map<String, PeerDevice> _pairedDevices = {};
  Map<String, PeerDevice> get pairedDevices => Map.unmodifiable(_pairedDevices);

  /// Loads saved paired devices from local persistent SharedPreferences storage
  Future<List<PeerDevice>> loadPairedDevices() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(jsonStr);
        _pairedDevices.clear();
        for (final item in list) {
          final peer = PeerDevice.fromJson(Map<String, dynamic>.from(item)).copyWith(isPaired: true);
          _pairedDevices[peer.deviceId] = peer;
        }
      }
    } catch (e) {
      debugPrint('Error loading paired devices: $e');
    }
    return _pairedDevices.values.toList();
  }

  /// Adds or updates a paired device in persistent storage
  Future<void> savePairedDevice(PeerDevice peer) async {
    final updatedPeer = peer.copyWith(isPaired: true);
    _pairedDevices[updatedPeer.deviceId] = updatedPeer;
    await _persist();
  }

  /// Removes a paired device from storage
  Future<void> removePairedDevice(String deviceId) async {
    _pairedDevices.remove(deviceId);
    await _persist();
  }

  /// Checks if a device ID is in the paired list
  bool isPaired(String deviceId) {
    return _pairedDevices.containsKey(deviceId);
  }

  /// Returns peer device by device ID if paired
  PeerDevice? getPairedDevice(String deviceId) {
    return _pairedDevices[deviceId];
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _pairedDevices.values.map((d) => d.toJson()).toList();
      await prefs.setString(_key, jsonEncode(list));
    } catch (e) {
      debugPrint('Error persisting paired devices: $e');
    }
  }
}
