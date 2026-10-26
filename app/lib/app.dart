import 'package:flutter/material.dart';

import 'features/home_shell.dart';
import 'features/pin_screen.dart';
import 'features/welcome_screen.dart';
import 'state/app_state.dart';
import 'theme/theme.dart';

class HotziApp extends StatefulWidget {
  const HotziApp({super.key, required this.state});

  final AppState state;

  @override
  State<HotziApp> createState() => _HotziAppState();
}

class _HotziAppState extends State<HotziApp> with WidgetsBindingObserver {
  final _navigator = GlobalKey<NavigatorState>();
  DateTime? _leftAt;

  /// Hotzi se reverrouille si le vendeur le quitte plus longtemps que ça.
  static const _lockAfter = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused) {
      _leftAt = DateTime.now();
    } else if (lifecycle == AppLifecycleState.resumed) {
      final leftAt = _leftAt;
      _leftAt = null;
      if (leftAt != null && DateTime.now().difference(leftAt) > _lockAfter && widget.state.unlocked) {
        // On ferme les écrans ouverts : rien ne doit rester visible derrière le verrou.
        _navigator.currentState?.popUntil((route) => route.isFirst);
        widget.state.lock();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return HotziScope(
      state: widget.state,
      child: MaterialApp(
        navigatorKey: _navigator,
        title: 'Hotzi',
        debugShowCheckedModeBanner: false,
        theme: buildHotziTheme(),
        home: const _Gate(),
      ),
    );
  }
}

/// Bienvenue au premier lancement, puis code secret, puis l'app.
class _Gate extends StatelessWidget {
  const _Gate();

  @override
  Widget build(BuildContext context) {
    final state = HotziScope.of(context);
    if (!state.hasPin) return const WelcomeScreen();
    if (!state.unlocked) return const PinScreen();
    return const HomeShell();
  }
}
