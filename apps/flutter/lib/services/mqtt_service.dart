import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/device.dart';

enum MqttStatus { disconnected, connecting, connected }

class MqttService {
  static const String brokerHost = 'broker.hivemq.com';
  static const int brokerPort = 8883;

  static const String topicPresenceOnlineWildcard =
      'meckchat/v1/presence/online/+';
  static const String topicPresenceOfflineWildcard =
      'meckchat/v1/presence/offline/+';
  static const String topicDiscovery = 'meckchat/v1/discovery';

  static String topicPresenceOnline(String deviceId) =>
      'meckchat/v1/presence/online/$deviceId';
  static String topicPresenceOffline(String deviceId) =>
      'meckchat/v1/presence/offline/$deviceId';

  MqttServerClient? _client;
  Device? _localDevice;
  MqttStatus _status = MqttStatus.disconnected;
  Timer? _heartbeatTimer;
  StreamSubscription? _subscriptionStream;

  // Callbacks
  void Function(MqttStatus status)? onStatusChanged;
  void Function(Device device)? onDevicePresenceReceived;
  void Function(String deviceId)? onDeviceOfflineReceived;

  MqttStatus get status => _status;
  bool get isConnected => _status == MqttStatus.connected;
  Device? get localDevice => _localDevice;

  /// Sets the local device configuration.
  void setLocalDevice(Device device) {
    _localDevice = device;
  }

  /// Connects to HiveMQ over TLS (8883).
  Future<void> connect(Device localDevice) async {
    _localDevice = localDevice;
    if (_status == MqttStatus.connecting || _status == MqttStatus.connected) {
      return;
    }

    _updateStatus(MqttStatus.connecting);
    debugPrint('[MQTT] Connecting to $brokerHost:$brokerPort (TLS)...');

    // Create client with unique client identifier
    final clientId = 'mc_${localDevice.deviceId}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    _client = MqttServerClient.withPort(brokerHost, clientId, brokerPort);
    _client!.secure = true;
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = true;
    _client!.resubscribeOnAutoReconnect = true;
    _client!.logging(on: false);

    // Setup Last Will and Testament (LWT)
    final willPayload = jsonEncode({
      'type': 'presence_offline',
      'device_id': localDevice.deviceId,
    });

    final connMessage = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .startClean()
        .withWillTopic(topicPresenceOffline(localDevice.deviceId))
        .withWillMessage(willPayload)
        .withWillQos(MqttQos.atLeastOnce)
        .withWillRetain();

    _client!.connectionMessage = connMessage;

    _client!.onConnected = _onConnected;
    _client!.onDisconnected = _onDisconnected;
    _client!.onAutoReconnect = _onAutoReconnect;
    _client!.onAutoReconnected = _onAutoReconnected;

    try {
      final res = await _client!.connect();
      if (res?.state == MqttConnectionState.connected) {
        _updateStatus(MqttStatus.connected);
      } else {
        debugPrint('[MQTT] Connection failed: state=${res?.state}');
        _updateStatus(MqttStatus.disconnected);
        _client?.disconnect();
      }
    } catch (e) {
      debugPrint('[MQTT] Exception during connection: $e');
      _updateStatus(MqttStatus.disconnected);
    }
  }

  void _onConnected() {
    debugPrint('[MQTT] Connected to HiveMQ broker!');
    _updateStatus(MqttStatus.connected);

    _setupSubscriptions();
    publishOnlinePresence();
    publishDiscoveryRequest();
    _startHeartbeat();
  }

  void _onDisconnected() {
    debugPrint('[MQTT] Disconnected from HiveMQ broker.');
    _updateStatus(MqttStatus.disconnected);
    _stopHeartbeat();
  }

  void _onAutoReconnect() {
    debugPrint('[MQTT] Auto-reconnecting to HiveMQ broker...');
    _updateStatus(MqttStatus.connecting);
    _stopHeartbeat();
  }

  void _onAutoReconnected() {
    debugPrint('[MQTT] Auto-reconnected to HiveMQ broker!');
    _updateStatus(MqttStatus.connected);
    _setupSubscriptions();
    publishOnlinePresence();
    publishDiscoveryRequest();
    _startHeartbeat();
  }

  void _updateStatus(MqttStatus newStatus) {
    _status = newStatus;
    onStatusChanged?.call(_status);
  }

  /// Sets up MQTT subscriptions and update listener.
  void _setupSubscriptions() {
    if (_client == null || _status != MqttStatus.connected) return;

    _client!.subscribe(topicPresenceOnlineWildcard, MqttQos.atLeastOnce);
    debugPrint('[MQTT] Subscribed: $topicPresenceOnlineWildcard');

    _client!.subscribe(topicPresenceOfflineWildcard, MqttQos.atLeastOnce);
    debugPrint('[MQTT] Subscribed: $topicPresenceOfflineWildcard');

    _client!.subscribe(topicDiscovery, MqttQos.atLeastOnce);
    debugPrint('[MQTT] Subscribed: $topicDiscovery');

    _subscriptionStream?.cancel();
    _subscriptionStream = _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final received in messages) {
        _handleIncomingMessage(received);
      }
    });
  }

  /// Processes an incoming MQTT message with self-filtering.
  void _handleIncomingMessage(MqttReceivedMessage<MqttMessage> received) {
    try {
      final topic = received.topic;
      final pubMsg = received.payload as MqttPublishMessage;
      final payloadStr =
          MqttPublishPayload.bytesToStringAsString(pubMsg.payload.message);

      if (payloadStr.isEmpty) return;

      final dynamic decoded = jsonDecode(payloadStr);
      if (decoded is! Map<String, dynamic>) return;

      final incomingDeviceId = decoded['device_id'] as String?;
      if (incomingDeviceId == null || incomingDeviceId.isEmpty) return;

      // Self-filtering: Ignore own presence messages
      if (_localDevice != null && incomingDeviceId == _localDevice!.deviceId) {
        return;
      }

      final type = decoded['type'] as String?;

      if (topic.startsWith('meckchat/v1/presence/online/')) {
        final device = Device.fromPresenceJson(decoded);
        if (device != null) {
          debugPrint(
              '[MQTT] Presence received from remote peer: name=${device.displayName}, id=${device.deviceId}, platform=${device.platform}');
          onDevicePresenceReceived?.call(device);
        }
      } else if (topic.startsWith('meckchat/v1/presence/offline/')) {
        debugPrint('[MQTT] Offline notice for peer: id=$incomingDeviceId');
        onDeviceOfflineReceived?.call(incomingDeviceId);
      } else if (topic == topicDiscovery) {
        if (type == 'discovery_request') {
          debugPrint(
              '[MQTT] Discovery request received from peer: id=$incomingDeviceId. Responding with online presence...');
          publishOnlinePresence();
        }
      }
    } catch (e) {
      debugPrint('[MQTT] Error processing message on topic ${received.topic}: $e');
    }
  }

  /// Publishes local device online presence (retained = true, QoS 1).
  void publishOnlinePresence() {
    if (_client == null || _status != MqttStatus.connected || _localDevice == null) {
      return;
    }

    try {
      final topic = topicPresenceOnline(_localDevice!.deviceId);
      final payload = _localDevice!.toPresenceOnlineJsonString();
      final builder = MqttClientPayloadBuilder().addString(payload);

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload,
          retain: true);
      debugPrint('[MQTT] Published online presence to $topic');
    } catch (e) {
      debugPrint('[MQTT] Failed to publish online presence: $e');
    }
  }

  /// Publishes local device offline presence cleanly.
  void publishOfflinePresence() {
    if (_client == null || _status != MqttStatus.connected || _localDevice == null) {
      return;
    }

    try {
      final topic = topicPresenceOffline(_localDevice!.deviceId);
      final payload = _localDevice!.toPresenceOfflineJsonString();
      final builder = MqttClientPayloadBuilder().addString(payload);

      _client!.publishMessage(topic, MqttQos.atLeastOnce, builder.payload,
          retain: true);
      debugPrint('[MQTT] Published offline presence to $topic');
    } catch (e) {
      debugPrint('[MQTT] Failed to publish offline presence: $e');
    }
  }

  /// Broadcasts a discovery request to `meckchat/v1/discovery`.
  void publishDiscoveryRequest() {
    if (_client == null || _status != MqttStatus.connected || _localDevice == null) {
      return;
    }

    try {
      final payload = jsonEncode({
        'type': 'discovery_request',
        'protocol_version': 1,
        'device_id': _localDevice!.deviceId,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      final builder = MqttClientPayloadBuilder().addString(payload);

      _client!.publishMessage(
          topicDiscovery, MqttQos.atLeastOnce, builder.payload,
          retain: false);
      debugPrint('[MQTT] Discovery request broadcasted to $topicDiscovery');
    } catch (e) {
      debugPrint('[MQTT] Failed to publish discovery request: $e');
    }
  }

  /// Starts the 30-second periodic heartbeat.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_status == MqttStatus.connected && _localDevice != null) {
        publishOnlinePresence();
      }
    });
  }

  /// Stops the heartbeat.
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  /// Disconnects cleanly.
  void disconnect() {
    _stopHeartbeat();
    _subscriptionStream?.cancel();
    _subscriptionStream = null;

    if (_status == MqttStatus.connected) {
      publishOfflinePresence();
    }

    _client?.disconnect();
    _client = null;
    _updateStatus(MqttStatus.disconnected);
    debugPrint('[MQTT] Disconnected from HiveMQ.');
  }

  void dispose() {
    disconnect();
  }
}
