import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_button.dart';
import 'plan_edit_screen.dart';
import 'ticket_screen.dart';

/// Vente au comptoir : forfait, quantité, moyen de paiement.
class SellTab extends StatefulWidget {
  const SellTab({super.key, required this.onNavigate});

  final ValueChanged<int> onNavigate;

  @override
  State<SellTab> createState() => _SellTabState();
}

class _SellTabState extends State<SellTab> {
  static const _maxQuantity = 20;

  int? _planId;
  int _quantity = 1;
  PaymentMethod _payment = PaymentMethod.cash;
  bool _busy = false;

  Future<void> _sell(Plan plan) async {
    setState(() => _busy = true);
    final state = HotziScope.read(context);
    final tickets = await state.sell(plan, _quantity, _payment);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _quantity = 1;
    });
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            TicketScreen(tickets: tickets, payment: _payment, justSold: true, onHome: () => widget.onNavigate(0)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plans = HotziScope.of(context).activePlans;
    if (plans.isEmpty) return const _NoPlan();
    final plan = plans.firstWhere((p) => p.id == _planId, orElse: () => plans.first);
    final total = plan.priceFcfa * _quantity;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            children: [
              Entrance(child: Text('Vendre un ticket', style: HotziText.display(28))),
              const SizedBox(height: 16),
              Entrance(
                delay: Entrance.step(1),
                child: const _Step(number: 1, title: 'Quel forfait ?'),
              ),
              const SizedBox(height: 8),
              for (final (index, option) in plans.indexed)
                Entrance(
                  delay: Entrance.step(index + 1),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PlanOption(
                      plan: option,
                      selected: option.id == plan.id,
                      onTap: () => setState(() => _planId = option.id),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Entrance(
                delay: Entrance.step(plans.length + 1),
                child: _Quantity(
                  quantity: _quantity,
                  onMinus: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  onPlus: _quantity < _maxQuantity ? () => setState(() => _quantity++) : null,
                ),
              ),
              const SizedBox(height: 18),
              Entrance(
                delay: Entrance.step(plans.length + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Step(number: 3, title: 'Comment le client a payé ?'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final (index, method) in PaymentMethod.values.indexed) ...[
                          if (index > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _PaymentOption(
                              method: method,
                              selected: method == _payment,
                              onTap: () => setState(() => _payment = method),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Noté dans ton historique. Hotzi ne vérifie pas le paiement.',
                      style: HotziText.body(13, color: HotziColors.ink3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: HotziColors.line)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'À encaisser',
                      style: HotziText.body(13, weight: FontWeight.w500, color: HotziColors.ink3),
                    ),
                    Text(Format.fcfa(total), style: HotziText.display(26)),
                  ],
                ),
              ),
              HotziButton(
                label: _quantity == 1 ? 'Créer le ticket' : 'Créer $_quantity tickets',
                style: HotziButtonStyle.mango,
                expand: false,
                onPressed: _busy ? null : () => _sell(plan),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title});

  final int number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$number. ',
            style: HotziText.body(15, weight: FontWeight.w700, color: HotziColors.violet),
          ),
          TextSpan(text: title),
        ],
      ),
      style: HotziText.body(15, weight: FontWeight.w700),
    );
  }
}

class _PlanOption extends StatelessWidget {
  const _PlanOption({required this.plan, required this.selected, required this.onTap});

  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = motion(context, const Duration(milliseconds: 220));
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: duration,
        decoration: BoxDecoration(
          color: selected ? HotziColors.violetTint : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? HotziColors.violet : HotziColors.line, width: selected ? 2 : 1),
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x245B2EE5), blurRadius: 16, offset: Offset(0, 6))]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              height: 70,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: duration,
                      width: 72,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? HotziColors.violet : HotziColors.violetSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        Format.shortDuration(plan.durationMinutes),
                        style: HotziText.display(16, color: selected ? Colors.white : HotziColors.violetDark),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(plan.name, style: HotziText.body(17, weight: FontWeight.w700)),
                    ),
                    Text(Format.fcfa(plan.priceFcfa), style: HotziText.display(19)),
                    const SizedBox(width: 10),
                    AnimatedSwitcher(
                      duration: duration,
                      transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                      child: selected
                          ? const CircleAvatar(
                              key: ValueKey('on'),
                              radius: 13,
                              backgroundColor: HotziColors.violet,
                              child: Icon(Icons.check_rounded, size: 17, color: Colors.white),
                            )
                          : Container(
                              key: const ValueKey('off'),
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFC9C0E3), width: 2),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Quantity extends StatelessWidget {
  const _Quantity({required this.quantity, required this.onMinus, required this.onPlus});

  final int quantity;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Step(number: 2, title: 'Combien ?'),
              Text(
                quantity == 1 ? '1 ticket' : '$quantity tickets',
                style: HotziText.body(14, color: HotziColors.ink2),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: HotziColors.line),
          ),
          child: Row(
            children: [
              _StepperButton(icon: Icons.remove_rounded, tooltip: 'Un ticket de moins', onPressed: onMinus),
              SizedBox(
                width: 44,
                child: Text('$quantity', textAlign: TextAlign.center, style: HotziText.display(24)),
              ),
              _StepperButton(icon: Icons.add_rounded, tooltip: 'Un ticket de plus', onPressed: onPlus),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: HotziColors.ground,
        fixedSize: const Size(50, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, color: HotziColors.ink),
    );
  }
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({required this.method, required this.selected, required this.onTap});

  final PaymentMethod method;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (method) {
      PaymentMethod.cash => Icons.payments_outlined,
      PaymentMethod.mobileMoney => Icons.phone_android_rounded,
      PaymentMethod.other => Icons.more_horiz_rounded,
    };
    final color = selected ? Colors.white : HotziColors.ink;
    return Semantics(
      selected: selected,
      child: AnimatedContainer(
        duration: motion(context, const Duration(milliseconds: 220)),
        decoration: BoxDecoration(
          color: selected ? HotziColors.violetDeep : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? HotziColors.violetDeep : HotziColors.line, width: 1.5),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 76,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: color, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    method.label,
                    textAlign: TextAlign.center,
                    style: HotziText.body(14, weight: FontWeight.w700, color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoPlan extends StatelessWidget {
  const _NoPlan();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.sell_outlined, size: 48, color: HotziColors.violet),
          const SizedBox(height: 12),
          Text('Aucun forfait en vente', style: HotziText.display(22), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            'Crée un forfait, ou remets-en un en vente dans l\'onglet Forfaits.',
            textAlign: TextAlign.center,
            style: HotziText.body(15, color: HotziColors.ink2),
          ),
          const SizedBox(height: 18),
          HotziButton(
            label: 'Créer un forfait',
            icon: Icons.add_rounded,
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PlanEditScreen())),
          ),
        ],
      ),
    );
  }
}
