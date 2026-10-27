import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../network/network.dart';
import '../../state/app_state.dart';
import '../../theme/colors.dart';
import '../../theme/text.dart';
import '../../widgets/entrance.dart';
import '../../widgets/hotzi_button.dart';

/// Le vendeur choisit le nom et le mot de passe de son Wi-Fi.
class WifiNameScreen extends StatefulWidget {
  const WifiNameScreen({super.key});

  @override
  State<WifiNameScreen> createState() => _WifiNameScreenState();
}

class _WifiNameScreenState extends State<WifiNameScreen> {
  final _form = GlobalKey<FormState>();
  late final NetworkState _initial = HotziScope.read(context).network;
  late final _ending = TextEditingController(text: WifiNaming.ending(_initial.networkName));
  late final _passphrase = TextEditingController(text: _initial.passphrase);
  bool _saving = false;

  @override
  void dispose() {
    _ending.dispose();
    _passphrase.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final ending = _ending.text.trim();
    final passphrase = _passphrase.text;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (ending == WifiNaming.ending(_initial.networkName) && passphrase == _initial.passphrase) {
      navigator.pop();
      return;
    }
    final state = HotziScope.read(context);
    final sessions = state.network.sessions.length;
    if (sessions > 0 && !await _confirm(sessions)) return;
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      await state.changeWifi(ending, passphrase);
    } on PlatformException {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(content: Text('Android a refusé ce nom ou ce mot de passe.')));
      return;
    }
    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          state.network.running ? 'Le Wi-Fi redémarre avec son nouveau nom' : 'Nom et mot de passe enregistrés',
        ),
      ),
    );
  }

  Future<bool> _confirm(int sessions) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer maintenant ?'),
        content: Text(
          '${sessions > 1 ? '$sessions téléphones ont' : 'Un téléphone a'} Internet en ce moment. '
          'Ils vont le perdre jusqu\'à ce qu\'ils rejoignent le nouveau Wi-Fi et entrent de nouveau leur code. '
          'Leur ticket continue de tourner.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Changer')),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: Text('Nom et mot de passe', style: HotziText.display(24))),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _form,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Entrance(
                      child: _Field(
                        label: 'Nom du Wi-Fi',
                        help: 'Android met toujours « ${WifiNaming.prefix} » devant. Tu choisis la suite.',
                        child: TextFormField(
                          controller: _ending,
                          maxLength: WifiNaming.maxEndingLength,
                          autocorrect: false,
                          style: HotziText.mono(17),
                          decoration: InputDecoration(
                            prefixText: WifiNaming.prefix,
                            prefixStyle: HotziText.mono(17, color: HotziColors.ink3),
                            hintText: 'ChezAwa',
                          ),
                          validator: (value) => WifiNaming.endingProblem((value ?? '').trim()),
                        ),
                      ),
                    ),
                    Entrance(
                      delay: Entrance.step(1),
                      child: _Field(
                        label: 'Mot de passe',
                        help: 'Au moins 8 caractères, sans espace ni accent. Tu le donnes aux clients.',
                        child: TextFormField(
                          controller: _passphrase,
                          maxLength: WifiNaming.maxPassphraseLength,
                          keyboardType: TextInputType.visiblePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          style: HotziText.mono(17),
                          decoration: const InputDecoration(counterText: ''),
                          validator: (value) => WifiNaming.passphraseProblem(value ?? ''),
                        ),
                      ),
                    ),
                    Entrance(
                      delay: Entrance.step(2),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: HotziColors.mangoSoft,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline_rounded, color: HotziColors.warn),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Les téléphones déjà réglés devront rejoindre le nouveau Wi-Fi '
                                'et régler de nouveau le proxy. Change-le plutôt quand personne n\'est connecté.',
                                style: HotziText.body(14, color: HotziColors.ink2, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: HotziButton(label: 'Enregistrer', height: 58, fontSize: 17, onPressed: _saving ? null : _save),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.help, required this.child});

  final String label;
  final String help;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: HotziText.body(15, weight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(help, style: HotziText.body(13, color: HotziColors.ink3, height: 1.4)),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
