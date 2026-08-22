import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device.dart';

typedef OnPresenceReceivedCallback = void Function(Map<String, dynamic> payload);
typedef OnSignalReceivedCallback = void Function(Map<String, dynamic> payload);

class MqttService {
  static final MqttService _instance = MqttService._internal();
  factory MqttService() => _instance;
  MqttService._internal();

  MqttServerClient? _client;
  LocalDevice? _localDevice;
  String _host = 'broker.hivemq.com';
  int _port = 8883;
  bool _useTls = true;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  OnPresenceReceivedCallback? onPresenceReceived;
  OnSignalReceivedCallback? onSignalReceived;
  VoidCallback? onConnectionStatusChanged;

  /// Initializes the MQTT client with local device identity and broker configuration
  Future<void> initialize({
    required LocalDevice localDevice,
    String host = 'broker.hivemq.com',
    int port = 8883,
    bool useTls = true,
  }) async {
    _localDevice = localDevice;
    _host = host;
    _port = port;
    _useTls = useTls;

    await connect();
  }

  /// Establishes MQTT connection over TLS to broker.hivemq.com
  Future<bool> connect() async {
    if (_localDevice == null) return false;
    final deviceId = _localDevice!.deviceId;
    final clientId = 'meckchat_$deviceId';

    // Cleanup previous client if existing
    disconnect();

    debugPrint('Initializing MQTT connection to $_host:$_port as client $clientId...');
    _client = MqttServerClient.withPort(_host, clientId, _port);
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;

    if (_useTls) {
      _client!.secure = true;
      _client!.useWebSocket = false;
      // Accept self-signed or default TLS certificates
      _client!.onBadCertificate = (dynamic cert) => true;
    }

    // Configure Last Will and Testament (LWT) for unexpected disconnects
    final lwtTopic = 'meckchat/v1/presence/offline/$deviceId';
    final lwtPayloadStr = jsonEncode({
      'protocol_version': '1.0',
      'device_id': deviceId,
      'status': 'offline',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillTopic(lwtTopic)
        .withWillMessage(lwtPayloadStr)
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain()
        .startClean();
    _client!.connectionMessage = connMessage;

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onSubscribed = _onSubscribed;

    try {
      final status = await _client!.connect();
      if (status?.state == MqttConnectionState.connected) {
        _isConnected = true;
        debugPrint('MQTT CONNECTED');
        _setupSubscriptionListeners();
        _subscribeToTopics();
        publishOnlinePresence();
        publishDiscoveryQuery();
        onConnectionStatusChanged?.call();
        return true;
      } else {
        debugPrint('MQTT connection failed: state ${status?.state}');
        _isConnected = false;
        _client!.disconnect();
        onConnectionStatusChanged?.call();
        return false;
      }
    } catch (e) {
      debugPrint('MQTT Exception during connect: $e');
      _isConnected = false;
      onConnectionStatusChanged?.call();
      return false;
    }
  }

  void _onConnected() {
    _isConnected = true;
    debugPrint('MQTT CONNECTED');
    onConnectionStatusChanged?.call();
  }

  void _onDisconnected() {
    _isConnected = false;
    debugPrint('MQTT DISCONNECTED');
    onConnectionStatusChanged?.call();
  }

  void _onSubscribed(String topic) {
    debugPrint('MQTT SUBSCRIBED: $topic');
  }

  void _subscribeToTopics() {
    if (_client == null || !_isConnected || _localDevice == null) return;

    const onlineTopic = 'meckchat/v1/presence/online/+';
    const offlineTopic = 'meckchat/v1/presence/offline/+';
    const discoveryTopic = 'meckchat/v1/discovery';
    final signalTopic = 'meckchat/v1/signal/${_localDevice!.deviceId}';

    _client!.subscribe(onlineTopic, MqttQos.atLeastOnce);
    _client!.subscribe(offlineTopic, MqttQos.atLeastOnce);
    _client!.subscribe(discoveryTopic, MqttQos.atMostOnce);
    _client!.subscribe(signalTopic, MqttQos.atLeastOnce);
  }

  void _setupSubscriptionListeners() {
    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage?>>? messages) {
      if (messages == null || messages.isEmpty) return;

      for (final received in messages) {
        final topic = received.topic;
        final recMess = received.payload as MqttPublishMessage;
        final payloadStr =
            MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final Map<String, dynamic> json = jsonDecode(payloadStr);

          if (topic.startsWith('meckchat/v1/presence/online/')) {
            final incomingDeviceId = json['device_id'] as String?;
            if (incomingDeviceId != null &&
                _localDevice != null &&
                incomingDeviceId == _localDevice!.deviceId) {
              // Self device filter — skip
              return;
            }
            final platformStr = (json['platform'] ?? 'unknown').toString();
            debugPrint(
                'MQTT PRESENCE RECEIVED: device_id=${_redact(incomingDeviceId)}, platform=$platformStr');
            onPresenceReceived?.call(json);
          } else if (topic.startsWith('meckchat/v1/presence/offline/')) {
            final incomingDeviceId = json['device_id'] as String?;
            if (incomingDeviceId != null &&
                _localDevice != null &&
                incomingDeviceId == _localDevice!.deviceId) {
              return;
            }
            debugPrint('PEER REMOVED: device_id=${_redact(incomingDeviceId)}');
            json['type'] = 'presence_offline';
            onPresenceReceived?.call(json);
          } else if (topic == 'meckchat/v1/discovery') {
            final requester = json['requester_device_id'] as String?;
            if (requester != null &&
                _localDevice != null &&
                requester != _localDevice!.deviceId) {
              // Peer requested discovery — re-publish our online presence
              publishOnlinePresence();
            }
          } else if (_localDevice != null &&
              topic == 'meckchat/v1/signal/${_localDevice!.deviceId}') {
            onSignalReceived?.call(json);
          }
        } catch (e) {
          debugPrint('Error parsing MQTT payload on topic $topic: $e');
        }
      }
    });
  }

  /// Publishes local device presence payload to HiveMQ online topic
  void publishOnlinePresence() {
    if (_client == null || !_isConnected || _localDevice == null) return;

    final topic = 'meckchat/v1/presence/online/${_localDevice!.deviceId}';
    final payload = {
      'protocol_version': '1.0',
      'device_id': _localDevice!.deviceId,
      'display_name': _localDevice!.displayName,
      'platform': _localDevice!.platform,
      'wireguard_public_key': _localDevice!.wireGuardPublicKey,
      'virtual_ip': _localDevice!.virtualIp,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
    debugPrint('MQTT PRESENCE PUBLISHED');
  }

  /// Publishes offline status payload upon graceful shutdown
  void publishOfflinePresence() {
    if (_client == null || !_isConnected || _localDevice == null) return;

    final topic = 'meckchat/v1/presence/offline/${_localDevice!.deviceId}';
    final payload = {
      'protocol_version': '1.0',
      'device_id': _localDevice!.deviceId,
      'status': 'offline',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: true);
  }

  /// Publishes discovery query asking online peers to re-announce presence
  void publishDiscoveryQuery() {
    if (_client == null || !_isConnected || _localDevice == null) return;

    const topic = 'meckchat/v1/discovery';
    final payload = {
      'action': 'QUERY_ONLINE_PEERS',
      'requester_device_id': _localDevice!.deviceId,
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!, retain: false);
  }

  /// Sends direct WireGuard signaling payload to target peer's signal topic
  void sendSignal(String targetDeviceId, Map<String, dynamic> signalPayload) {
    if (!assertNoChatDataInMqtt(signalPayload)) {
      throw ArgumentError('DATA PLANE ISOLATION VIOLATION: Chat or file data cannot be published to MQTT!');
    }
    if (_client == null || !_isConnected) {
      debugPrint('Cannot send MQTT signal: Client not connected.');
      return;
    }

    final topic = 'meckchat/v1/signal/$targetDeviceId';
    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(signalPayload));
    _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!, retain: false);
    debugPrint('MQTT SIGNAL PUBLISHED to $topic');
  }

  /// Asserts that NO chat content, file bytes, or private keys can be published to MQTT
  static bool assertNoChatDataInMqtt(Map<String, dynamic> payload) {
    final str = jsonEncode(payload).toLowerCase();
    return !str.contains('chat_message') &&
        !str.contains('file_chunk') &&
        !str.contains('file_bytes') &&
        !str.contains('private_key') &&
        !str.contains('chat_content');
  }

  void disconnect() {
    if (_client != null) {
      try {
        publishOfflinePresence();
        _client!.disconnect();
      } catch (_) {}
      _client = null;
    }
    _isConnected = false;
  }

  String _redact(String? str) {
    if (str == null || str.isEmpty) return 'none';
    if (str.length <= 6) return '***';
    return '${str.substring(0, 3)}...${str.substring(str.length - 3)}';
  }
}
