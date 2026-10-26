import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_button.dart';
import '../widgets/hotzi_logo.dart';
import 'pin_screen.dart';

/// Premier lancement : présentation, puis choix du code secret.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _choosingPin = false;

  @override
  Widget build(BuildContext context) {
    if (_choosingPin) {
      return PinScreen(creating: true, onCancel: () => setState(() => _choosingPin = false));
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                const Spacer(),
                Entrance(
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: HotziColors.violet,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: const [BoxShadow(color: Color(0x4D5B2EE5), blurRadius: 28, offset: Offset(0, 12))],
                    ),
                    alignment: Alignment.center,
                    child: const HotziLogo(size: 72, animate: true),
                  ),
                ),
                const SizedBox(height: 22),
                Entrance(
                  delay: Entrance.step(1),
                  child: Text('Bienvenue sur Hotzi', textAlign: TextAlign.center, style: HotziText.display(30)),
                ),
                const SizedBox(height: 6),
                Entrance(
                  delay: Entrance.step(2),
                  child: Text(
                    'Ton téléphone. Ton Wi-Fi. Tes revenus.',
                    textAlign: TextAlign.center,
                    style: HotziText.body(17, color: HotziColors.ink2),
                  ),
                ),
                const SizedBox(height: 28),
                Entrance(
                  delay: Entrance.step(3),
                  child: const _Point(icon: Icons.sell_outlined, text: 'Choisis tes forfaits et tes prix.'),
                ),
                Entrance(
                  delay: Entrance.step(4),
                  child: const _Point(
                    icon: Icons.confirmation_number_outlined,
                    text: 'Vends des tickets avec un QR code.',
                  ),
                ),
                Entrance(
                  delay: Entrance.step(5),
                  child: const _Point(icon: Icons.insights_rounded, text: 'Suis tes ventes de la journée.'),
                ),
                const Spacer(flex: 2),
                Entrance(
                  delay: Entrance.step(6),
                  child: Column(
                    children: [
                      Text(
                        'D\'abord, choisis un code secret. Il protège tes ventes.',
                        textAlign: TextAlign.center,
                        style: HotziText.body(15, color: HotziColors.ink2),
                      ),
                      const SizedBox(height: 14),
                      HotziButton(
                        label: 'Choisir mon code secret',
                        icon: Icons.lock_outline_rounded,
                        style: HotziButtonStyle.mango,
                        height: 60,
                        fontSize: 18,
                        onPressed: () => setState(() => _choosingPin = true),
                      ),
                    ],
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

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: HotziColors.violetSoft, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: HotziColors.violetDark, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: HotziText.body(16, weight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
