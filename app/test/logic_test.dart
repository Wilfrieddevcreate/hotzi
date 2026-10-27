import 'package:flutter_test/flutter_test.dart';
import 'package:hotzi/data/format.dart';
import 'package:hotzi/data/memory_repository.dart';
import 'package:hotzi/data/models.dart';
import 'package:hotzi/data/ticket_codes.dart';
import 'package:hotzi/network/network.dart';
import 'package:hotzi/state/app_state.dart';

import 'fake_network.dart';

void main() {
  group('Codes des tickets', () {
    test('8 caractères, sans caractères ambigus', () {
      for (var i = 0; i < 200; i++) {
        final code = TicketCodes.generate();
        expect(code.length, TicketCodes.length);
        expect(code.split('').every(TicketCodes.alphabet.contains), isTrue);
        expect(RegExp('[01OI]').hasMatch(code), isFalse);
      }
    });

    test('normalise et met en forme comme la bibliothèque réseau', () {
      expect(TicketCodes.normalize(' k7qm-4xpa '), 'K7QM4XPA');
      expect(TicketCodes.format('K7QM4XPA'), 'K7QM-4XPA');
    });
  });

  group('Mise en forme', () {
    test('montants en FCFA', () {
      expect(Format.fcfa(50), '50 FCFA');
      expect(Format.fcfa(2200), '2 200 FCFA');
      expect(Format.fcfa(1250000, plain: true), '1 250 000 FCFA');
    });

    test('durées', () {
      expect(Format.shortDuration(30), '30 min');
      expect(Format.shortDuration(90), '1 h 30');
      expect(Format.shortDuration(1440), '24 h');
      expect(Format.longDuration(60), '1 heure');
      expect(Format.longDuration(360), '6 heures');
    });

    test('dates', () {
      final date = DateTime(2026, 10, 26, 9, 5);
      expect(Format.day(date), 'Lundi 26 octobre');
      expect(Format.when(date, DateTime(2026, 10, 26, 18)), '09:05');
      expect(Format.when(date, DateTime(2026, 10, 27, 8)), '26/10 09:05');
    });
  });

  group('Ventes', () {
    late AppState state;
    late FakeNetwork network;
    var now = DateTime(2026, 10, 26, 14, 32);

    setUp(() async {
      now = DateTime(2026, 10, 26, 14, 32);
      network = FakeNetwork();
      state = AppState(MemoryRepository(), network, clock: () => now);
      await state.load();
    });

    test('les 4 forfaits de démonstration sont là', () {
      expect(state.plans.map((p) => p.name), ['Mini', 'Standard', 'Confort', 'Journée']);
    });

    test('vendre crée un ticket disponible et note la vente', () async {
      final standard = state.plans.firstWhere((p) => p.name == 'Standard');
      final tickets = await state.sell(standard, 3, PaymentMethod.mobileMoney);

      expect(tickets, hasLength(3));
      expect(tickets.map((t) => t.code).toSet(), hasLength(3));
      expect(tickets.every((t) => t.status == TicketStatus.available), isTrue);
      expect(state.salesByTicket[tickets.first.id]?.payment, PaymentMethod.mobileMoney);

      final summary = state.today();
      expect(summary.totalFcfa, 300);
      expect(summary.ticketsSold, 3);
      expect(summary.available, 3);
    });

    test('changer le prix d\'un forfait ne change pas un ticket déjà vendu', () async {
      final mini = state.plans.firstWhere((p) => p.name == 'Mini');
      final sold = (await state.sell(mini, 1, PaymentMethod.cash)).single;
      await state.savePlan(mini.copyWith(priceFcfa: 75));

      expect(state.plans.firstWhere((p) => p.id == mini.id).priceFcfa, 75);
      expect(state.tickets.single.priceFcfa, 50);
      expect(state.salesByTicket[sold.id]?.amountFcfa, 50);
    });

    test('les ventes de la veille ne comptent pas aujourd\'hui', () async {
      final mini = state.plans.first;
      await state.sell(mini, 2, PaymentMethod.cash);
      now = DateTime(2026, 10, 27, 8);
      expect(state.today().totalFcfa, 0);
      expect(state.today().available, 2);
    });

    test('un forfait caché ne se vend plus', () async {
      final journee = state.plans.firstWhere((p) => p.name == 'Journée');
      await state.savePlan(journee.copyWith(active: false));
      expect(state.activePlans.map((p) => p.name), isNot(contains('Journée')));
    });

    test('code secret : choisi, vérifié, verrouillé', () async {
      expect(state.hasPin, isFalse);
      await state.setPin('2580');
      expect(state.unlocked, isTrue);
      state.lock();
      expect(state.unlock('1111'), isFalse);
      expect(state.unlocked, isFalse);
      expect(state.unlock('2580'), isTrue);
    });

    test('le Wi-Fi ne démarre pas sans autorisation, ni Wi-Fi éteint', () async {
      network.permissionsGranted = false;
      expect(await state.startWifi(), WifiStartProblem.permissions);
      network
        ..permissionsGranted = true
        ..wifiOn = false;
      expect(await state.startWifi(), WifiStartProblem.wifiOff);
      expect(network.commands, isNot(contains('start')));

      network.wifiOn = true;
      expect(await state.startWifi(), isNull);
      expect(network.commands, contains('start'));
    });

    test('l\'état du Wi-Fi arrive dans l\'app, et les tickets sont relus quand ils changent', () async {
      var notified = 0;
      state.addListener(() => notified++);
      network.emit(const NetworkState(running: true, controlActive: true, ticketsVersion: 0));
      await pumpEventQueue();
      expect(state.network.controlActive, isTrue);

      final mini = state.plans.first;
      final sold = (await state.sell(mini, 1, PaymentMethod.cash)).single;
      await state.revoke(sold);
      expect(network.commands, contains('revoke ${sold.code}'));

      final before = notified;
      network.emit(const NetworkState(running: true, controlActive: true, ticketsVersion: 1));
      await pumpEventQueue();
      expect(notified, greaterThan(before));
    });
  });
}
