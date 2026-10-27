import 'dart:async';

import 'package:hotzi/network/network.dart';

/// Wi-Fi simulé : les tests choisissent l'état envoyé et voient les commandes reçues.
class FakeNetwork implements HotziNetwork {
  final _states = StreamController<NetworkState>.broadcast();
  final commands = <String>[];
  bool permissionsGranted = true;
  bool wifiOn = true;
  bool battery = true;

  void emit(NetworkState state) => _states.add(state);

  @override
  Stream<NetworkState> get states => _states.stream;

  @override
  Future<bool> requestPermissions() async => permissionsGranted;

  @override
  Future<bool> wifiEnabled() async => wifiOn;

  @override
  Future<void> openWifiSettings() async => commands.add('openWifiSettings');

  @override
  Future<void> start() async => commands.add('start');

  @override
  Future<void> stop() async => commands.add('stop');

  @override
  Future<void> revoke(String code) async => commands.add('revoke $code');

  @override
  Future<bool> batteryExempt() async => battery;

  @override
  Future<void> askBatteryExemption() async => commands.add('askBatteryExemption');
}
