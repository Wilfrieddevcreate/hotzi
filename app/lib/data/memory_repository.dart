import 'models.dart';
import 'repository.dart';
import 'ticket_codes.dart';

/// Données en mémoire, pour les tests.
class MemoryRepository implements HotziRepository {
  MemoryRepository({List<Plan>? plans}) {
    for (final plan in plans ?? demoPlans(DateTime(2026))) {
      _plans.add(plan.copyWith(id: ++_lastId));
    }
  }

  final _plans = <Plan>[];
  final _tickets = <Ticket>[];
  final _sales = <Sale>[];
  final _settings = <String, String>{};

  /// Les tests n'ont pas besoin d'empreinte : la vraie est calculée côté Kotlin.
  String? _pin;
  var _lastId = 0;

  @override
  Future<List<Plan>> plans() async => List.of(_plans);

  @override
  Future<Plan> savePlan(Plan plan) async {
    if (plan.id == null) {
      final created = plan.copyWith(id: ++_lastId);
      _plans.add(created);
      return created;
    }
    _plans[_plans.indexWhere((p) => p.id == plan.id)] = plan;
    return plan;
  }

  @override
  Future<List<Ticket>> tickets() async => _tickets.reversed.toList();

  @override
  Future<List<Sale>> sales() async => _sales.reversed.toList();

  @override
  Future<List<Ticket>> sell(Plan plan, int quantity, PaymentMethod payment, DateTime at) async {
    final created = <Ticket>[];
    for (var i = 0; i < quantity; i++) {
      final ticket = Ticket(
        id: ++_lastId,
        code: TicketCodes.generate(),
        planId: plan.id,
        planName: plan.name,
        durationMinutes: plan.durationMinutes,
        priceFcfa: plan.priceFcfa,
        createdAt: at,
      );
      _tickets.add(ticket);
      _sales.add(Sale(id: ++_lastId, ticketId: ticket.id!, soldAt: at, amountFcfa: plan.priceFcfa, payment: payment));
      created.add(ticket);
    }
    return created;
  }

  @override
  Future<String?> setting(String key) async => _settings[key];

  @override
  Future<void> saveSetting(String key, String value) async {
    _settings[key] = value;
  }

  @override
  Future<bool> hasPin() async => _pin != null;

  @override
  Future<void> savePin(String pin) async => _pin = pin;

  @override
  Future<bool> checkPin(String pin) async => _pin != null && pin == _pin;
}
