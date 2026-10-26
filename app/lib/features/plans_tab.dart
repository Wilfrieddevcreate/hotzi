import 'package:flutter/material.dart';

import '../data/format.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/colors.dart';
import '../theme/text.dart';
import '../widgets/entrance.dart';
import '../widgets/hotzi_button.dart';
import 'plan_edit_screen.dart';

class PlansTab extends StatelessWidget {
  const PlansTab({super.key});

  void _edit(BuildContext context, [Plan? plan]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlanEditScreen(plan: plan)));

  @override
  Widget build(BuildContext context) {
    final plans = HotziScope.of(context).plans;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Entrance(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Forfaits', style: HotziText.display(28)),
                    Text('Tes prix, à changer quand tu veux.', style: HotziText.body(15, color: HotziColors.ink2)),
                  ],
                ),
              ),
              HotziButton(
                label: 'Ajouter',
                icon: Icons.add_rounded,
                expand: false,
                height: 48,
                fontSize: 15,
                onPressed: () => _edit(context),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final (index, plan) in plans.indexed)
          Entrance(
            delay: Entrance.step(index + 1),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PlanCard(plan: plan, onEdit: () => _edit(context, plan)),
            ),
          ),
        Entrance(
          delay: Entrance.step(plans.length + 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: HotziColors.ink2),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Un ticket déjà vendu garde son prix, même si tu changes le forfait.',
                  style: HotziText.body(14, color: HotziColors.ink2),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.onEdit});

  final Plan plan;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final on = plan.active;
    final nameColor = on ? HotziColors.ink : HotziColors.grayText;
    return AnimatedContainer(
      duration: motion(context, const Duration(milliseconds: 250)),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      decoration: BoxDecoration(
        color: on ? Colors.white : const Color(0xFFF1EEF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HotziColors.line),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: on ? HotziColors.violetSoft : const Color(0xFFE6E3EE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  Format.shortDuration(plan.durationMinutes),
                  style: HotziText.display(16, color: on ? HotziColors.violetDark : HotziColors.grayText),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: HotziText.body(17, weight: FontWeight.w700, color: nameColor),
                    ),
                    Text(
                      'Internet pendant ${Format.longDuration(plan.durationMinutes)}',
                      style: HotziText.body(13, color: HotziColors.ink3),
                    ),
                    if (plan.description.isNotEmpty)
                      Text(plan.description, style: HotziText.body(13, color: HotziColors.ink3)),
                  ],
                ),
              ),
              Text(Format.fcfa(plan.priceFcfa), style: HotziText.display(19, color: nameColor)),
            ],
          ),
          const Divider(height: 18, color: HotziColors.divider),
          Row(
            children: [
              Expanded(
                child: MergeSemantics(
                  child: Row(
                    children: [
                      Switch(
                        value: on,
                        onChanged: (value) => HotziScope.read(context).savePlan(plan.copyWith(active: value)),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          on ? 'Proposé à la vente' : 'Caché à la vente',
                          style: HotziText.body(
                            14,
                            weight: FontWeight.w700,
                            color: on ? HotziColors.okText : HotziColors.grayText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                style: TextButton.styleFrom(
                  backgroundColor: HotziColors.violetTint,
                  foregroundColor: HotziColors.violet,
                  minimumSize: const Size(0, 44),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  'Modifier',
                  style: HotziText.body(14, weight: FontWeight.w700, color: HotziColors.violet),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
