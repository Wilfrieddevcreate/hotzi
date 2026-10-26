import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_logo.dart';

/// Le Wi-Fi n'est pas encore relié à l'app : on l'explique au lieu d'afficher
/// des boutons qui ne feraient rien.
class WifiTab extends StatelessWidget {
  const WifiTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Entrance(child: Text('Ton Wi-Fi', style: HotziText.display(28))),
        const SizedBox(height: 14),
        Entrance(
          delay: Entrance.step(1),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: HotziColors.violetDeep, borderRadius: BorderRadius.circular(22)),
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const HotziLogo(size: 62, animate: true),
                ),
                const SizedBox(height: 14),
                Text(
                  'Bientôt ici',
                  textAlign: TextAlign.center,
                  style: HotziText.body(20, weight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'On termine les tests sur le téléphone. Ensuite, c\'est ici que tu allumeras le Wi-Fi Hotzi '
                  'et que tu verras les téléphones connectés.',
                  textAlign: TextAlign.center,
                  style: HotziText.body(15, color: HotziColors.onDeep, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Entrance(
          delay: Entrance.step(2),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: HotziColors.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('En attendant', style: HotziText.display(18, weight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final text in const [
                  'Crée tes forfaits et fixe tes prix.',
                  'Vends des tickets : ils sont gardés sur ton téléphone.',
                  'Les tickets vendus marcheront dès que le Wi-Fi sera relié.',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20, color: HotziColors.ok),
                        const SizedBox(width: 10),
                        Expanded(child: Text(text, style: HotziText.body(15))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
