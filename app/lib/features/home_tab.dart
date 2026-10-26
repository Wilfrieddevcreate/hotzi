import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/ticket_codes.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_button.dart';
import '../widgets/hotzi_logo.dart';
import '../widgets/nav_bar.dart';
import 'plan_edit_screen.dart';
import 'ticket_screen.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final state = HotziScope.of(context);
    final summary = state.today();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Entrance(
          child: _Header(onLock: state.lock, today: Format.day(state.now)),
        ),
        const SizedBox(height: 14),
        Entrance(
          delay: Entrance.step(1),
          child: _WifiCard(onMore: () => onNavigate(4)),
        ),
        const SizedBox(height: 14),
        Entrance(
          delay: Entrance.step(2),
          child: HotziButton(
            label: 'Vendre un ticket',
            icon: Icons.confirmation_number_outlined,
            style: HotziButtonStyle.mango,
            height: 64,
            fontSize: 18,
            onPressed: () => onNavigate(HotziNavBar.sellIndex),
          ),
        ),
        const SizedBox(height: 14),
        Entrance(
          delay: Entrance.step(3),
          child: _SalesCard(summary: summary),
        ),
        const SizedBox(height: 14),
        Entrance(
          delay: Entrance.step(4),
          child: Row(
            children: [
              Expanded(
                child: HotziButton(
                  label: 'Voir les tickets',
                  icon: Icons.receipt_long_outlined,
                  style: HotziButtonStyle.soft,
                  fontSize: 15,
                  onPressed: () => onNavigate(1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HotziButton(
                  label: 'Nouveau forfait',
                  icon: Icons.add_rounded,
                  style: HotziButtonStyle.outline,
                  fontSize: 15,
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlanEditScreen())),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Entrance(delay: Entrance.step(5), child: const _LatestSales()),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLock, required this.today});

  final VoidCallback onLock;
  final String today;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: HotziColors.violet, borderRadius: BorderRadius.circular(14)),
          alignment: Alignment.center,
          child: const HotziLogo(size: 32, animate: true),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bonjour', style: HotziText.display(22, height: 1.1)),
              Text(today, style: HotziText.body(14, color: HotziColors.ink3)),
            ],
          ),
        ),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: HotziColors.line),
          ),
          child: IconButton(
            onPressed: onLock,
            tooltip: 'Verrouiller Hotzi',
            icon: const Icon(Icons.lock_outline_rounded, color: HotziColors.ink2),
          ),
        ),
      ],
    );
  }
}

/// Tant que le réseau n'est pas branché, on le dit : jamais de faux « tout va bien ».
class _WifiCard extends StatelessWidget {
  const _WifiCard({required this.onMore});

  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: HotziColors.violetDeep, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: HotziColors.onDeep),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Wi-Fi pas encore relié',
                  style: HotziText.body(17, weight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tes forfaits, tickets et ventes sont bien gardés. Le Wi-Fi sera branché ici après le test sur le téléphone.',
            style: HotziText.body(14, color: HotziColors.onDeep, height: 1.45),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onMore,
            style: TextButton.styleFrom(foregroundColor: Colors.white, padding: EdgeInsets.zero),
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              'En savoir plus',
              style: HotziText.body(14, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final tickets = summary.ticketsSold;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HotziColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ventes du jour',
            style: HotziText.body(14, weight: FontWeight.w500, color: HotziColors.ink3),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: summary.totalFcfa.toDouble()),
            duration: motion(context, const Duration(milliseconds: 900)),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Text(Format.fcfa(value.round()), style: HotziText.display(36, height: 1.2)),
          ),
          Text(
            '$tickets ${tickets > 1 ? 'tickets vendus' : 'ticket vendu'} · total que tu as noté',
            style: HotziText.body(13, color: HotziColors.ink3),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _CountTile(
                count: summary.available,
                label: 'Disponibles',
                background: HotziColors.violetSoft,
                color: HotziColors.violetDark,
              ),
              const SizedBox(width: 8),
              _CountTile(
                count: summary.active,
                label: 'En cours',
                background: HotziColors.okSoft,
                color: HotziColors.okText,
              ),
              const SizedBox(width: 8),
              _CountTile(
                count: summary.finished,
                label: 'Terminés',
                background: HotziColors.graySoft,
                color: HotziColors.grayText,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.count, required this.label, required this.background, required this.color});

  final int count;
  final String label;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$count', style: HotziText.display(24, color: color)),
            Text(
              label,
              style: HotziText.body(13, weight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestSales extends StatelessWidget {
  const _LatestSales();

  @override
  Widget build(BuildContext context) {
    final state = HotziScope.of(context);
    final latest = state.tickets.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dernières ventes', style: HotziText.display(18, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (latest.isEmpty)
          Text(
            'Pas encore de vente. Appuie sur « Vendre un ticket ».',
            style: HotziText.body(15, color: HotziColors.ink2),
          ),
        for (final ticket in latest)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: HotziColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute<void>(builder: (_) => TicketScreen(tickets: [ticket]))),
                title: Text(TicketCodes.format(ticket.code), style: HotziText.mono(15)),
                subtitle: Text(
                  '${ticket.planName} · ${Format.when(ticket.createdAt, state.now)}'
                  '${state.salesByTicket[ticket.id]?.payment.label.prefixed(' · ') ?? ''}',
                  style: HotziText.body(13, color: HotziColors.ink3),
                ),
                trailing: Text(Format.fcfa(ticket.priceFcfa), style: HotziText.body(15, weight: FontWeight.w800)),
              ),
            ),
          ),
      ],
    );
  }
}

extension on String {
  String prefixed(String prefix) => '$prefix$this';
}
