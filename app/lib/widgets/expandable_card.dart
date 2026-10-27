import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text.dart';

/// Bloc blanc qui s'ouvre d'un appui (« Détails techniques », « Le client a un iPhone ? »).
/// Posé sur un vrai [Material] pour que l'effet d'appui reste visible.
class ExpandableCard extends StatelessWidget {
  const ExpandableCard({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HotziColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        title: Text(
          title,
          style: HotziText.body(15, weight: FontWeight.w700, color: HotziColors.ink2),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
