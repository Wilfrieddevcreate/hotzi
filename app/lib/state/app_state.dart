import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/models.dart';
import '../data/repository.dart';
import '../network/network.dart';

/// Résumé affiché sur l'accueil.
class DaySummary {
  const DaySummary({
    required this.totalFcfa,
    required this.ticketsSold,
    required this.available,
    required this.active,
    required this.finished,
  });

  final int totalFcfa;
  final int ticketsSold;
  final int available;
  final int active;
  final int finished;
}

/// État de l'app vendeur : forfaits, tickets, ventes, Wi-Fi et verrouillage.
class AppState extends ChangeNotifier {
  AppState(this._repository, this._network, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final HotziRepository _repository;
  final HotziNetwork _network;
  final DateTime Function() _clock;
  StreamSubscription<NetworkState>? _networkUpdates;

  List<Plan> plans = const [];
  List<Ticket> tickets = const [];
  Map<int, Sale> salesByTicket = const {};
  NetworkState network = const NetworkState();
  String? _pin;
  bool unlocked = false;

  DateTime get now => _clock();
  List<Plan> get activePlans => plans.where((plan) => plan.active).toList();
  bool get hasPin => _pin != null;

  Future<void> load() async {
    await Future.wait([_reloadPlans(notify: false), _reloadTickets(notify: false)]);
    _pin = await _repository.setting(_pinKey);
    _networkUpdates ??= _network.states.listen(_onNetwork);
    notifyListeners();
  }

  @override
  void dispose() {
    _networkUpdates?.cancel();
    super.dispose();
  }

  /// Allume le Wi-Fi Hotzi. Renvoie ce qui l'en empêche, ou null s'il démarre.
  Future<WifiStartProblem?> startWifi() async {
    if (!await _network.requestPermissions()) return WifiStartProblem.permissions;
    if (!await _network.wifiEnabled()) return WifiStartProblem.wifiOff;
    await _network.start();
    return null;
  }

  Future<void> stopWifi() => _network.stop();

  Future<void> openWifiSettings() => _network.openWifiSettings();

  /// Annule un ticket : s'il est en cours, Internet est coupé tout de suite sur ce téléphone.
  Future<void> revoke(Ticket ticket) => _network.revoke(ticket.code);

  Future<bool> batteryExempt() => _network.batteryExempt();

  Future<void> askBatteryExemption() => _network.askBatteryExemption();

  void _onNetwork(NetworkState next) {
    final ticketsChanged = next.ticketsVersion != network.ticketsVersion;
    network = next;
    if (ticketsChanged) {
      _reloadTickets();
    } else {
      notifyListeners();
    }
  }

  /// Le code PIN reste sur le téléphone, dans la base privée de l'app.
  Future<void> setPin(String pin) async {
    await _repository.saveSetting(_pinKey, pin);
    _pin = pin;
    unlocked = true;
    notifyListeners();
  }

  bool unlock(String pin) {
    if (pin != _pin) return false;
    unlocked = true;
    notifyListeners();
    return true;
  }

  void lock() {
    unlocked = false;
    notifyListeners();
  }

  Future<Plan> savePlan(Plan plan) async {
    final saved = await _repository.savePlan(plan);
    await _reloadPlans();
    return saved;
  }

  Future<List<Ticket>> sell(Plan plan, int quantity, PaymentMethod payment) async {
    final created = await _repository.sell(plan, quantity, payment, _clock());
    await _reloadTickets();
    return created;
  }

  DaySummary today() {
    final now = _clock();
    bool isToday(DateTime date) => date.year == now.year && date.month == now.month && date.day == now.day;
    final todaySales = salesByTicket.values.where((sale) => isToday(sale.soldAt));
    int count(TicketStatus status) => tickets.where((ticket) => ticket.status == status).length;
    return DaySummary(
      totalFcfa: todaySales.fold(0, (sum, sale) => sum + sale.amountFcfa),
      ticketsSold: todaySales.length,
      available: count(TicketStatus.available),
      active: count(TicketStatus.active),
      finished: count(TicketStatus.expired),
    );
  }

  Future<void> _reloadPlans({bool notify = true}) async {
    plans = await _repository.plans();
    if (notify) notifyListeners();
  }

  Future<void> _reloadTickets({bool notify = true}) async {
    tickets = await _repository.tickets();
    salesByTicket = {for (final sale in await _repository.sales()) sale.ticketId: sale};
    if (notify) notifyListeners();
  }

  static const _pinKey = 'pin';
}

/// Donne accès à [AppState] à tous les écrans.
class HotziScope extends InheritedNotifier<AppState> {
  const HotziScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<HotziScope>()!.notifier!;

  /// Pour les actions (boutons) : ne reconstruit pas l'écran quand l'état change.
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<HotziScope>()!.notifier!;
}
