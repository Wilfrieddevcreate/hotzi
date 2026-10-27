import 'package:flutter/material.dart';

import '../../network/network.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../theme/text.dart';

/// Allume le Wi-Fi Hotzi en expliquant, en mots simples, ce qui l'en empêche.
Future<void> startWifi(BuildContext context) async {
  final state = HotziScope.read(context);
  final problem = await state.startWifi();
  if (!context.mounted || problem == null) return;
  switch (problem) {
    case WifiStartProblem.permissions:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hotzi a besoin de ton autorisation pour créer le Wi-Fi. Réessaie et accepte.')),
      );
    case WifiStartProblem.wifiOff:
      final open = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Allume le Wi-Fi'),
          content: const Text(
            'Le Wi-Fi du téléphone doit être allumé, sans être connecté à un réseau. '
            'Allume-le, puis reviens appuyer sur « Allumer le Wi-Fi ».',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Plus tard')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ouvrir les réglages')),
          ],
        ),
      );
      if (open ?? false) await state.openWifiSettings();
  }
}

/// Demande confirmation avant de couper Internet à un client.
Future<bool> confirmCut(BuildContext context, {required String what}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Couper Internet $what ?'),
      content: const Text('Le ticket sera annulé. Le client devra acheter un nouveau ticket.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: HotziColors.danger),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Oui, couper'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Point vert qui bat doucement quand le Wi-Fi est allumé. Immobile si le
/// téléphone demande de réduire les animations.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, this.color = HotziColors.ok, this.size = 12});

  final Color color;
  final double size;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOut.transform(_controller.value);
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.55 * (1 - t)),
                spreadRadius: 12 * t,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ligne « titre + valeur à recopier » (nom du Wi-Fi, mot de passe…).
class CopyValue extends StatelessWidget {
  const CopyValue({super.key, required this.label, required this.value, required this.onCopy});

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
      decoration: BoxDecoration(color: HotziColors.ground, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: HotziText.body(13, weight: FontWeight.w600, color: HotziColors.ink3),
                ),
                SelectableText(value, style: HotziText.mono(17)),
              ],
            ),
          ),
          IconButton(
            onPressed: onCopy,
            tooltip: 'Copier : $label',
            icon: const Icon(Icons.copy_rounded, color: HotziColors.violet),
          ),
        ],
      ),
    );
  }
}
