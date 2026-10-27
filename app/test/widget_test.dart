import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotzi/app.dart';
import 'package:hotzi/data/memory_repository.dart';
import 'package:hotzi/data/models.dart';
import 'package:hotzi/network/network.dart';
import 'package:hotzi/state/app_state.dart';

import 'fake_network.dart';

late FakeNetwork network;

Future<AppState> _pumpApp(WidgetTester tester, {String? pin}) async {
  // Animations coupées, comme pour un utilisateur qui les a désactivées.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  network = FakeNetwork();
  final state = AppState(MemoryRepository(), network);
  await state.load();
  if (pin != null) await state.setPin(pin);
  await tester.pumpWidget(HotziApp(state: state));
  await tester.pumpAndSettle();
  return state;
}

Future<void> _typePin(WidgetTester tester, String pin) async {
  for (final digit in pin.split('')) {
    await tester.tap(find.text(digit));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('premier lancement : bienvenue, puis choix du code secret', (tester) async {
    final state = await _pumpApp(tester);
    expect(find.text('Bienvenue sur Hotzi'), findsOneWidget);

    await tester.tap(find.text('Choisir mon code secret'));
    await tester.pumpAndSettle();
    expect(find.text('Choisis ton code secret'), findsOneWidget);

    await _typePin(tester, '2580');
    expect(find.text('Tape-le encore une fois'), findsOneWidget);
    await _typePin(tester, '2580');

    expect(state.hasPin, isTrue);
    expect(find.text('Vendre un ticket'), findsOneWidget);
  });

  testWidgets('un mauvais code secret n\'ouvre pas Hotzi', (tester) async {
    final state = await _pumpApp(tester, pin: '2580');
    state.lock();
    await tester.pumpAndSettle();

    await _typePin(tester, '1111');
    expect(find.text('Ce n\'est pas le bon code.'), findsOneWidget);
    expect(state.unlocked, isFalse);

    await _typePin(tester, '2580');
    expect(state.unlocked, isTrue);
  });

  testWidgets('vendre un ticket affiche le ticket et le compte dans les ventes', (tester) async {
    final state = await _pumpApp(tester, pin: '2580');

    await tester.tap(find.text('Vendre').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Standard'));
    await tester.pump();
    // Avec 4 forfaits, le choix du paiement est plus bas : on fait défiler.
    await tester.scrollUntilVisible(find.text('Mobile Money'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Mobile Money'));
    await tester.pump();
    await tester.tap(find.text('Créer le ticket'));
    await tester.pumpAndSettle();

    expect(find.text('Ticket prêt'), findsOneWidget);
    expect(find.text('Vente notée'), findsOneWidget);
    expect(state.tickets, hasLength(1));
    expect(state.tickets.single.planName, 'Standard');
    expect(state.today().totalFcfa, 100);
  });

  testWidgets('le Wi-Fi éteint se rallume depuis l\'accueil, et l\'accueil ne dit « protégé » qu\'une fois prêt', (
    tester,
  ) async {
    await _pumpApp(tester, pin: '2580');
    expect(find.text('Ton Wi-Fi est éteint'), findsOneWidget);
    expect(find.text('Protégés'), findsNothing);

    await tester.tap(find.text('Allumer le Wi-Fi'));
    await tester.pumpAndSettle();
    expect(network.commands, contains('start'));

    network.emit(const NetworkState(running: true));
    // Le petit indicateur de démarrage tourne sans fin : on avance juste d'un pas.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Démarrage du Wi-Fi…'), findsOneWidget);
    expect(find.text('Protégés'), findsNothing);

    network.emit(const NetworkState(running: true, controlActive: true));
    await tester.pumpAndSettle();
    expect(find.text('Ton Wi-Fi est allumé'), findsOneWidget);
    expect(find.text('Protégés'), findsOneWidget);

    network.emit(const NetworkState(running: true, error: 'Le proxy s\'est arrêté.'));
    await tester.pumpAndSettle();
    expect(find.text('Les tickets ne sont plus protégés'), findsOneWidget);
  });

  testWidgets('couper un client depuis l\'onglet Wi-Fi annule son ticket', (tester) async {
    final state = await _pumpApp(tester, pin: '2580');
    final sold = (await state.sell(state.plans.first, 1, PaymentMethod.cash)).single;
    network.emit(
      NetworkState(
        running: true,
        controlActive: true,
        proxyHost: '192.168.49.1',
        sessions: [
          NetworkSession(
            code: sold.code,
            planName: 'Mini',
            clientIp: '192.168.49.23',
            remaining: const Duration(minutes: 12),
            connections: 3,
          ),
        ],
      ),
    );
    await tester.tap(find.text('Wi-Fi').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('1 téléphone avec Internet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 téléphone avec Internet'), findsOneWidget);
    expect(find.textContaining('Il reste 12 min'), findsOneWidget);

    await tester.ensureVisible(find.text('Couper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Couper'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oui, couper'));
    await tester.pumpAndSettle();
    expect(network.commands, contains('revoke ${sold.code}'));
  });

  testWidgets('le vendeur change le nom et le mot de passe du Wi-Fi', (tester) async {
    await _pumpApp(tester, pin: '2580');
    await tester.tap(find.text('Wi-Fi').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Changer le nom ou le mot de passe'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Changer le nom ou le mot de passe'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'Chez Aïcha');
    await tester.enterText(fields.last, 'court');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lettres sans accents'), findsOneWidget);
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);
    expect(network.commands.where((command) => command.startsWith('changeWifi')), isEmpty);

    await tester.enterText(fields.first, ' Chez Awa ');
    await tester.enterText(fields.last, 'awa2026!');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(network.commands, contains('changeWifi DIRECT-hz-Chez Awa / awa2026!'));
    expect(find.text('Nom et mot de passe enregistrés'), findsOneWidget);
  });
}
