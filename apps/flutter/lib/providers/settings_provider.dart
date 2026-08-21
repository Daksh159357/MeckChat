import 'package:flutter/foundation.dart';

class SettingsProvider with ChangeNotifier {
  String _mqttHost = 'broker.hivemq.com';
  int _mqttPort = 8883;
  bool _useTls = true;

  String get mqttHost => _mqttHost;
  int get mqttPort => _mqttPort;
  bool get useTls => _useTls;

  void updateMqttSettings({
    required String host,
    required int port,
    required bool useTls,
  }) {
    _mqttHost = host;
    _mqttPort = port;
    _useTls = useTls;
    notifyListeners();
  }
}
