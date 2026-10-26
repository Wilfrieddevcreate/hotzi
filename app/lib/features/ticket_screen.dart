import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../data/ticket_codes.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_button.dart';
import 'ticket/ticket_card.dart';
import 'ticket/ticket_export.dart';

/// Un ou plusieurs tickets à montrer, partager ou imprimer.
/// Avec [justSold], affiche la confirmation de la vente.
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.tickets, this.payment, this.justSold = false, this.onHome});

  final List<Ticket> tickets;
  final PaymentMethod? payment;
  final bool justSold;
  final VoidCallback? onHome;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final _pages = PageController();
  late final _cards = [for (final _ in widget.tickets) GlobalKey()];
  int _page = 0;
  bool _sharing = false;

  Ticket get _current => widget.tickets[_page];

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String get _title {
    if (!widget.justSold) return 'Ticket';
    return widget.tickets.length == 1 ? 'Ticket prêt' : '${widget.tickets.length} tickets prêts';
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: TicketCodes.format(_current.code)));
    _say('Code copié');
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    final boundary = _cards[_page].currentContext?.findRenderObject() as RenderRepaintBoundary?;
    final shared = await TicketExport.shareImage(boundary, _current);
    if (!mounted) return;
    setState(() => _sharing = false);
    if (!shared) _say('L\'image du ticket n\'a pas pu être préparée. Réessaie.');
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.tickets.fold(0, (sum, ticket) => sum + ticket.priceFcfa);
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
                  Text(_title, style: HotziText.display(24)),
                ],
              ),
            ),
            if (widget.justSold)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: _SoldBanner(
                  text: '${Format.fcfa(total)}${widget.payment == null ? '' : ' · ${widget.payment!.label}'}',
                ),
              ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.tickets.length,
                onPageChanged: (page) => setState(() => _page = page),
                itemBuilder: (context, index) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Entrance(
                    delay: const Duration(milliseconds: 150),
                    child: RepaintBoundary(
                      key: _cards[index],
                      child: TicketCard(ticket: widget.tickets[index]),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.tickets.length > 1) _PageDots(count: widget.tickets.length, page: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Action(icon: Icons.copy_rounded, label: 'Copier', onTap: _copy),
                      const SizedBox(width: 8),
                      _Action(icon: Icons.share_rounded, label: 'Partager', onTap: _sharing ? null : _share),
                      const SizedBox(width: 8),
                      _Action(
                        icon: Icons.print_outlined,
                        label: widget.tickets.length > 1 ? 'Tout imprimer' : 'Imprimer',
                        onTap: () => TicketExport.printTickets(widget.tickets),
                      ),
                    ],
                  ),
                  if (widget.justSold) ...[
                    const SizedBox(height: 12),
                    HotziButton(label: 'Vendre un autre ticket', onPressed: () => Navigator.of(context).pop()),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onHome?.call();
                      },
                      child: Text(
                        'Retour à l\'accueil',
                        style: HotziText.body(15, weight: FontWeight.w700, color: HotziColors.violet),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SoldBanner extends StatelessWidget {
  const _SoldBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.3, end: 1),
          duration: motion(context, const Duration(milliseconds: 600)),
          curve: Curves.elasticOut,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: const CircleAvatar(
            radius: 23,
            backgroundColor: HotziColors.ok,
            child: Icon(Icons.check_rounded, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vente notée', style: HotziText.body(17, weight: FontWeight.w800)),
              Text(text, style: HotziText.body(14, color: HotziColors.ink2)),
            ],
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.page});

  final int count;
  final int page;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ticket ${page + 1} sur $count',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: motion(context, const Duration(milliseconds: 250)),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == page ? 26 : 9,
              height: 9,
              decoration: BoxDecoration(
                color: i == page ? HotziColors.violet : const Color(0xFFD9D2EE),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          const SizedBox(width: 10),
          Text(
            '${page + 1} sur $count',
            style: HotziText.body(14, weight: FontWeight.w700, color: HotziColors.violet),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HotziColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 64,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: onTap == null ? HotziColors.ink3 : HotziColors.ink),
                const SizedBox(height: 4),
                Text(label, style: HotziText.body(13, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
