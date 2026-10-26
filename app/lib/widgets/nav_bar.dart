import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text.dart';
import 'entrance.dart';

/// Barre du bas : Accueil, Tickets, Vendre (mis en avant), Forfaits, Wi-Fi.
class HotziNavBar extends StatelessWidget {
  const HotziNavBar({super.key, required this.index, required this.onSelect});

  final int index;
  final ValueChanged<int> onSelect;

  static const sellIndex = 2;
  static const _items = [
    (Icons.home_rounded, 'Accueil'),
    (Icons.confirmation_number_outlined, 'Tickets'),
    (Icons.add_rounded, 'Vendre'),
    (Icons.sell_outlined, 'Forfaits'),
    (Icons.wifi_rounded, 'Wi-Fi'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: HotziColors.line)),
      ),
      child: SafeArea(
        top: false,
        // Les libellés suivent le réglage de taille du texte, dans une limite qui garde la barre lisible.
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: SizedBox(
            height: 72,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: _items[i].$1,
                      label: _items[i].$2,
                      selected: i == index,
                      raised: i == sellIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.raised,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool raised;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? HotziColors.violet : HotziColors.ink2;
    final labelStyle = HotziText.body(
      13,
      weight: selected ? FontWeight.w700 : FontWeight.w500,
      color: raised && !selected ? HotziColors.ink : color,
    );
    final text = Text(label, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: labelStyle);
    // Le bouton Vendre dépasse au-dessus de la barre sans changer sa hauteur.
    final content = raised
        ? Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned(
                top: -18,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: HotziColors.mango,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: const [BoxShadow(color: Color(0x59FF8A3D), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Icon(icon, size: 26, color: HotziColors.ink),
                ),
              ),
              Positioned(left: 0, right: 0, bottom: 8, child: Center(child: text)),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: motion(context, const Duration(milliseconds: 250)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                decoration: BoxDecoration(
                  color: selected ? HotziColors.violetSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 3),
              text,
            ],
          );
    return Semantics(
      selected: selected,
      button: true,
      excludeSemantics: true,
      label: label,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}
