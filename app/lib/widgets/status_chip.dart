import 'package:flutter/material.dart';

import '../data/models.dart';
import '../theme/colors.dart';
import '../theme/text.dart';

/// Couleurs d'un statut : le texte reste lisible, la couleur ne porte jamais seule l'information.
(Color background, Color foreground) statusColors(TicketStatus status) => switch (status) {
  TicketStatus.available => (HotziColors.violetSoft, HotziColors.violetDark),
  TicketStatus.active => (HotziColors.okSoft, HotziColors.okText),
  TicketStatus.expired => (HotziColors.graySoft, HotziColors.grayText),
  TicketStatus.revoked => (HotziColors.dangerSoft, HotziColors.danger),
};

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = statusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        status.label,
        style: HotziText.body(12, weight: FontWeight.w700, color: foreground),
      ),
    );
  }
}
