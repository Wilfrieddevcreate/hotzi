import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/format.dart';
import '../data/ticket_codes.dart';
import '../network/network.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/expandable_card.dart';
import '../widgets/hotzi_button.dart';
import '../widgets/hotzi_logo.dart';
import 'help_client_screen.dart';
import 'wifi/wifi_actions.dart';

/// Le Wi-Fi Hotzi : l'allumer, ce qu'il faut donner au client, qui est connecté, et si tout va bien.
class WifiTab extends StatefulWidget {
  const WifiTab({super.key});

  @override
  State<WifiTab> createState() => _WifiTabState();
}

class _WifiTabState extends State<WifiTab> with WidgetsBindingObserver {
  bool? _batteryExempt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkBattery();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Au retour des réglages Android, on revérifie l'économie de batterie.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkBattery();
  }

  Future<void> _checkBattery() async {
    final exempt = await HotziScope.read(context).batteryExempt();
    if (mounted) setState(() => _batteryExempt = exempt);
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copié')));
  }

  Future<void> _stop(NetworkState network) async {
    final state = HotziScope.read(context);
    if (network.sessions.isNotEmpty) {
      final count = network.sessions.length;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Éteindre le Wi-Fi ?'),
          content: Text(count > 1 ? '$count clients vont perdre Internet.' : 'Un client va perdre Internet.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Éteindre')),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await state.stopWifi();
  }

  Future<void> _cut(NetworkSession session) async {
    final state = HotziScope.read(context);
    if (!await confirmCut(context, what: 'sur ce téléphone')) return;
    final ticket = state.tickets.where((t) => t.code == session.code).firstOrNull;
    if (ticket != null) await state.revoke(ticket);
  }

  @override
  Widget build(BuildContext context) {
    final network = HotziScope.of(context).network;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Entrance(child: Text('Ton Wi-Fi', style: HotziText.display(28))),
        const SizedBox(height: 14),
        Entrance(delay: Entrance.step(1), child: _hero(network)),
        const SizedBox(height: 14),
        Entrance(delay: Entrance.step(2), child: _forClient(network)),
        const SizedBox(height: 14),
        Entrance(delay: Entrance.step(3), child: _sessions(network)),
        const SizedBox(height: 14),
        Entrance(delay: Entrance.step(4), child: _checks(network)),
        const SizedBox(height: 14),
        Entrance(delay: Entrance.step(5), child: _technical(network)),
      ],
    );
  }

  Widget _hero(NetworkState network) {
    final (title, subtitle) = switch (network) {
      NetworkState(controlActive: true) => (
        'Ton Wi-Fi est allumé',
        '${network.runningSince == null ? '' : 'Depuis ${Format.time(network.runningSince!)} · '}les tickets sont protégés',
      ),
      NetworkState(failing: true) => ('Les tickets ne sont plus protégés', 'Personne n\'a Internet. ${network.error}'),
      NetworkState(starting: true) => ('Démarrage du Wi-Fi…', 'Quelques secondes.'),
      _ => ('Ton Wi-Fi est éteint', 'Les clients ne peuvent pas se connecter.'),
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: network.failing ? HotziColors.warn : HotziColors.violetDeep,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: network.running
                ? const HotziLogo(size: 54, animate: true)
                : const Icon(Icons.wifi_off_rounded, color: HotziColors.onDeep, size: 40),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: HotziText.body(20, weight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: HotziText.body(14, color: const Color(0xFFE9E4FA), height: 1.4),
          ),
          const SizedBox(height: 14),
          network.running
              ? HotziButton(
                  label: 'Éteindre le Wi-Fi',
                  icon: Icons.power_settings_new_rounded,
                  style: HotziButtonStyle.outline,
                  height: 52,
                  onPressed: () => _stop(network),
                )
              : HotziButton(
                  label: 'Allumer le Wi-Fi',
                  icon: Icons.power_settings_new_rounded,
                  style: HotziButtonStyle.mango,
                  height: 52,
                  onPressed: () => startWifi(context),
                ),
        ],
      ),
    );
  }

  Widget _forClient(NetworkState network) {
    return _Card(
      title: 'À donner au client',
      children: [
        CopyValue(
          label: 'Nom du Wi-Fi',
          value: network.networkName,
          onCopy: () => _copy('Nom du Wi-Fi', network.networkName),
        ),
        const SizedBox(height: 8),
        CopyValue(
          label: 'Mot de passe',
          value: network.passphrase,
          onCopy: () => _copy('Mot de passe', network.passphrase),
        ),
        const SizedBox(height: 12),
        HotziButton(
          label: 'Aider un client à se connecter',
          icon: Icons.help_outline_rounded,
          style: HotziButtonStyle.mango,
          fontSize: 15,
          onPressed: () =>
              Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const HelpClientScreen())),
        ),
      ],
    );
  }

  Widget _sessions(NetworkState network) {
    final sessions = network.sessions;
    return _Card(
      title: sessions.length > 1
          ? '${sessions.length} téléphones avec Internet'
          : '${sessions.length} téléphone avec Internet',
      children: [
        if (sessions.isEmpty)
          Text(
            network.controlActive ? 'Aucun client pour le moment.' : 'Allume le Wi-Fi pour voir les clients.',
            style: HotziText.body(15, color: HotziColors.ink2),
          ),
        for (final (index, session) in sessions.indexed) ...[
          if (index > 0) const Divider(color: HotziColors.divider, height: 16),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: HotziColors.okSoft, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.phone_android_rounded, color: HotziColors.okText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.planName} · ${TicketCodes.format(session.code)}',
                      style: HotziText.body(15, weight: FontWeight.w700),
                    ),
                    Text(
                      'Il reste ${Format.remaining(session.remaining)} · ${session.clientIp}',
                      style: HotziText.body(13, color: HotziColors.ink3),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: () => _cut(session),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HotziColors.danger,
                  side: const BorderSide(color: Color(0xFFF5C2BC)),
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('Couper'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _checks(NetworkState network) {
    return _Card(
      title: 'Tout fonctionne ?',
      children: [
        _Check(ok: network.controlActive, text: 'Les tickets sont protégés'),
        _Check(
          ok: network.running && network.upstreamAvailable,
          text: network.running && network.upstream.isNotEmpty
              ? 'Ton téléphone a Internet (${network.upstream})'
              : 'Ton téléphone a Internet',
        ),
        _Check(
          ok: _batteryExempt ?? false,
          text: 'Hotzi reste allumé écran éteint',
          action: _batteryExempt == false
              ? TextButton(onPressed: () => HotziScope.read(context).askBatteryExemption(), child: const Text('Régler'))
              : null,
        ),
      ],
    );
  }

  Widget _technical(NetworkState network) {
    return ExpandableCard(
      title: 'Détails techniques',
      children: [
        Text('Proxy : ${network.proxyHost ?? '192.168.49.1'} · port ${network.proxyPort}', style: HotziText.mono(14)),
        Text('Portail : http://hotzi.wifi', style: HotziText.mono(14)),
        Text('Type de réseau : Wi-Fi Direct', style: HotziText.body(14)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HotziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: HotziText.display(18, weight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.ok, required this.text, this.action});

  final bool ok;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: ok ? HotziColors.okSoft : HotziColors.mangoSoft, shape: BoxShape.circle),
            child: Icon(
              ok ? Icons.check_rounded : Icons.priority_high_rounded,
              size: 17,
              color: ok ? HotziColors.okText : HotziColors.warn,
              semanticLabel: ok ? 'OK' : 'À vérifier',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: HotziText.body(15))),
          ?action,
        ],
      ),
    );
  }
}
