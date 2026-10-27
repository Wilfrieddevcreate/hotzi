import 'package:flutter/services.dart';

/// Un client qui a Internet en ce moment.
class NetworkSession {
  const NetworkSession({
    required this.code,
    required this.planName,
    required this.clientIp,
    required this.remaining,
    required this.connections,
  });

  final String code;
  final String planName;
  final String clientIp;
  final Duration remaining;
  final int connections;

  factory NetworkSession.fromMap(Map<Object?, Object?> map) => NetworkSession(
    code: map['code'] as String,
    planName: map['planName'] as String,
    clientIp: map['clientIp'] as String,
    remaining: Duration(milliseconds: map['remainingMs'] as int),
    connections: map['connections'] as int,
  );
}

/// État du Wi-Fi Hotzi, tel que l'envoie la bibliothèque réseau.
class NetworkState {
  const NetworkState({
    this.running = false,
    this.runningSince,
    this.controlActive = false,
    this.networkName = 'DIRECT-hz-Hotzi',
    this.passphrase = 'hotzi2026',
    this.proxyHost,
    this.proxyPort = 8282,
    this.upstream = '',
    this.upstreamAvailable = false,
    this.error,
    this.ticketsVersion = 0,
    this.sessions = const [],
  });

  final bool running;
  final DateTime? runningSince;

  /// Vrai seulement si le Wi-Fi et le proxy tournent vraiment : sinon, on n'affiche jamais « protégé ».
  final bool controlActive;
  final String networkName;
  final String passphrase;
  final String? proxyHost;
  final int proxyPort;
  final String upstream;
  final bool upstreamAvailable;
  final String? error;

  /// Change à chaque activation, fin ou annulation de ticket côté réseau.
  final int ticketsVersion;
  final List<NetworkSession> sessions;

  /// Le Wi-Fi tourne mais ne protège pas encore (démarrage) ou plus (panne).
  bool get starting => running && !controlActive && error == null;
  bool get failing => running && !controlActive && error != null;

  factory NetworkState.fromMap(Map<Object?, Object?> map) => NetworkState(
    running: map['running'] as bool,
    runningSince: switch (map['runningSince']) {
      final int millis => DateTime.fromMillisecondsSinceEpoch(millis),
      _ => null,
    },
    controlActive: map['controlActive'] as bool,
    networkName: map['networkName'] as String,
    passphrase: map['passphrase'] as String,
    proxyHost: map['proxyHost'] as String?,
    proxyPort: map['proxyPort'] as int,
    upstream: map['upstream'] as String,
    upstreamAvailable: map['upstreamAvailable'] as bool,
    error: map['error'] as String?,
    ticketsVersion: map['ticketsVersion'] as int,
    sessions: [
      for (final session in map['sessions'] as List<Object?>) NetworkSession.fromMap(session as Map<Object?, Object?>),
    ],
  );
}

/// Pourquoi le Wi-Fi n'a pas pu démarrer.
enum WifiStartProblem { permissions, wifiOff }

/// Commandes du Wi-Fi Hotzi.
abstract interface class HotziNetwork {
  Stream<NetworkState> get states;

  /// Demande les autorisations manquantes ; renvoie vrai si tout est accordé.
  Future<bool> requestPermissions();
  Future<bool> wifiEnabled();
  Future<void> openWifiSettings();
  Future<void> start();
  Future<void> stop();

  /// Annule un ticket et coupe tout de suite Internet au téléphone qui l'utilise.
  Future<void> revoke(String code);
  Future<bool> batteryExempt();
  Future<void> askBatteryExemption();
}

/// Le Wi-Fi Hotzi de la bibliothèque réseau Kotlin.
class NativeNetwork implements HotziNetwork {
  static const _channel = MethodChannel('hotzi/network');
  static const _events = EventChannel('hotzi/network/state');

  @override
  late final Stream<NetworkState> states = _events.receiveBroadcastStream().map(
    (event) => NetworkState.fromMap(event as Map<Object?, Object?>),
  );

  @override
  Future<bool> requestPermissions() async => await _channel.invokeMethod<bool>('requestPermissions') ?? false;

  @override
  Future<bool> wifiEnabled() async => await _channel.invokeMethod<bool>('wifiEnabled') ?? false;

  @override
  Future<void> openWifiSettings() => _channel.invokeMethod<void>('openWifiSettings');

  @override
  Future<void> start() => _channel.invokeMethod<void>('start');

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> revoke(String code) => _channel.invokeMethod<void>('revoke', {'code': code});

  @override
  Future<bool> batteryExempt() async => await _channel.invokeMethod<bool>('batteryExempt') ?? false;

  @override
  Future<void> askBatteryExemption() => _channel.invokeMethod<void>('askBatteryExemption');
}
