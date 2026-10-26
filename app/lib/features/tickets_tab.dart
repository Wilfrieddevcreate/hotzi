import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../data/ticket_codes.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/status_chip.dart';
import 'ticket_screen.dart';

/// Historique des ventes : recherche et filtre par statut.
class TicketsTab extends StatefulWidget {
  const TicketsTab({super.key});

  @override
  State<TicketsTab> createState() => _TicketsTabState();
}

class _TicketsTabState extends State<TicketsTab> {
  String _query = '';
  TicketStatus? _filter;

  bool _matches(Ticket ticket, Sale? sale) {
    if (_filter != null && ticket.status != _filter) return false;
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return true;
    final code = TicketCodes.normalize(query);
    return (code.isNotEmpty && ticket.code.contains(code)) ||
        ticket.planName.toLowerCase().contains(query) ||
        (sale?.payment.label.toLowerCase().contains(query) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final state = HotziScope.of(context);
    final shown = state.tickets.where((t) => _matches(t, state.salesByTicket[t.id])).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          child: Entrance(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tickets', style: HotziText.display(28)),
                Text('Tout ce que tu as vendu.', style: HotziText.body(15, color: HotziColors.ink2)),
                const SizedBox(height: 14),
                TextField(
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  style: HotziText.body(16),
                  decoration: const InputDecoration(
                    labelText: 'Chercher un ticket',
                    hintText: 'Ex. : K7QM ou Standard',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _FilterChip(label: 'Tous', selected: _filter == null, onTap: () => setState(() => _filter = null)),
                    for (final status in TicketStatus.values)
                      _FilterChip(
                        label: status.label,
                        selected: _filter == status,
                        onTap: () => setState(() => _filter = status),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    state.tickets.isEmpty ? 'Aucun ticket vendu pour l\'instant.' : 'Aucun ticket ne correspond.',
                    textAlign: TextAlign.center,
                    style: HotziText.body(15, color: HotziColors.ink2),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => Entrance(
                    delay: Entrance.step(index),
                    child: _TicketRow(ticket: shown[index], sale: state.salesByTicket[shown[index].id], now: state.now),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: motion(context, const Duration(milliseconds: 200)),
        decoration: BoxDecoration(
          color: selected ? HotziColors.violet : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? HotziColors.violet : HotziColors.line, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Text(
                label,
                style: HotziText.body(14, weight: FontWeight.w700, color: selected ? Colors.white : HotziColors.ink),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketRow extends StatelessWidget {
  const _TicketRow({required this.ticket, required this.sale, required this.now});

  final Ticket ticket;
  final Sale? sale;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = statusColors(ticket.status);
    final soldAt = sale?.soldAt ?? ticket.createdAt;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HotziColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TicketScreen(tickets: [ticket]))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  Format.shortDuration(ticket.durationMinutes),
                  style: HotziText.display(12, color: foreground, letterSpacing: 0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(TicketCodes.format(ticket.code), style: HotziText.mono(15)),
                    Text(
                      [ticket.planName, Format.when(soldAt, now), ?sale?.payment.label].join(' · '),
                      style: HotziText.body(13, color: HotziColors.ink3),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(Format.fcfa(ticket.priceFcfa), style: HotziText.body(15, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  StatusChip(ticket.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
