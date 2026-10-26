import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/nav_bar.dart';
import 'home_tab.dart';
import 'plans_tab.dart';
import 'sell_tab.dart';
import 'tickets_tab.dart';
import 'wifi_tab.dart';

/// Les cinq onglets de l'app vendeur.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _go(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    final tab = switch (_index) {
      0 => HomeTab(onNavigate: _go),
      1 => const TicketsTab(),
      2 => SellTab(onNavigate: _go),
      3 => const PlansTab(),
      _ => const WifiTab(),
    };
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        // Chaque onglet est reconstruit à l'ouverture pour rejouer son apparition.
        body: SafeArea(
          bottom: false,
          child: KeyedSubtree(key: ValueKey(_index), child: tab),
        ),
        bottomNavigationBar: HotziNavBar(index: _index, onSelect: _go),
      ),
    );
  }
}
