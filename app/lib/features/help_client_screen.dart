import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/expandable_card.dart';
import '../widgets/hotzi_button.dart';

/// À montrer au client, ou à faire pour lui : à régler une seule fois par téléphone.
class HelpClientScreen extends StatelessWidget {
  const HelpClientScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final network = HotziScope.of(context).network;
    final proxyHost = network.proxyHost ?? '192.168.49.1';
    final steps = [
      _StepData(
        title: 'Se connecter au Wi-Fi',
        text: 'Ouvre Réglages, puis Wi-Fi, et choisis ce réseau :',
        values: [('Nom du Wi-Fi', network.networkName), ('Mot de passe', network.passphrase)],
      ),
      _StepData(
        title: 'Ouvrir les réglages du réseau',
        text:
            'Appuie longtemps sur ${network.networkName}, puis sur « Modifier ». '
            'Sur certains téléphones, c\'est la petite roue à côté du nom.',
      ),
      _StepData(
        title: 'Régler le proxy',
        text: 'Ouvre « Options avancées ». À « Proxy », choisis « Manuel », écris ces deux valeurs, puis enregistre :',
        values: [('Nom d\'hôte', proxyHost), ('Port', '${network.proxyPort}')],
      ),
      const _StepData(
        title: 'Entrer le code du ticket',
        text:
            'Ouvre le navigateur, tape l\'adresse ci-dessous et entre le code du ticket. Le temps démarre à ce moment-là.',
        values: [('Adresse', 'http://hotzi.wifi')],
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Retour',
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(child: Text('Aider un client', style: HotziText.display(24))),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Entrance(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Montre cet écran au client, ou fais-le pour lui. À faire '),
                          TextSpan(
                            text: 'une seule fois',
                            style: HotziText.body(15, weight: FontWeight.w800),
                          ),
                          const TextSpan(text: ' par téléphone.'),
                        ],
                      ),
                      style: HotziText.body(15, color: HotziColors.ink2, height: 1.45),
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final (index, step) in steps.indexed)
                    Entrance(
                      delay: Entrance.step(index + 1),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _Step(number: index + 1, step: step),
                      ),
                    ),
                  Entrance(
                    delay: Entrance.step(steps.length + 1),
                    child: ExpandableCard(
                      title: 'Le client a un iPhone ?',
                      children: [
                        Text(
                          'Réglages › Wi-Fi › touche (i) à côté du réseau › Proxy HTTP › Manuel. '
                          'Serveur $proxyHost, port ${network.proxyPort}.',
                          style: HotziText.body(15, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: HotziButton(
                label: 'C\'est fait',
                style: HotziButtonStyle.mango,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepData {
  const _StepData({required this.title, required this.text, this.values = const []});

  final String title;
  final String text;
  final List<(String, String)> values;
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.step});

  final int number;
  final _StepData step;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HotziColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: HotziColors.violet,
            child: Text('$number', style: HotziText.display(18, color: Colors.white)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(step.title, style: HotziText.display(19, weight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(step.text, style: HotziText.body(16, height: 1.45)),
                for (final (label, value) in step.values) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: HotziColors.ground, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: HotziText.body(12, weight: FontWeight.w600, color: HotziColors.ink3),
                        ),
                        SelectableText(value, style: HotziText.mono(18)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
