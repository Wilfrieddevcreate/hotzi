import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotzi/app.dart';
import 'package:hotzi/data/memory_repository.dart';
import 'package:hotzi/state/app_state.dart';

Future<AppState> _pumpApp(WidgetTester tester, {String? pin}) async {
  // Animations coupées, comme pour un utilisateur qui les a désactivées.
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final state = AppState(MemoryRepository());
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
}
