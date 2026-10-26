import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text.dart';
import 'entrance.dart';

enum HotziButtonStyle { mango, violet, soft, outline }

/// Gros bouton du design : s'enfonce légèrement quand on appuie dessus.
class HotziButton extends StatefulWidget {
  const HotziButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.style = HotziButtonStyle.violet,
    this.height = 56,
    this.fontSize = 16,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final HotziButtonStyle style;
  final double height;
  final double fontSize;
  final bool expand;

  @override
  State<HotziButton> createState() => _HotziButtonState();
}

class _HotziButtonState extends State<HotziButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final (background, foreground, border) = switch (widget.style) {
      HotziButtonStyle.mango => (HotziColors.mango, HotziColors.ink, null),
      HotziButtonStyle.violet => (HotziColors.violet, Colors.white, null),
      HotziButtonStyle.soft => (HotziColors.violetSoft, HotziColors.violetDark, null),
      HotziButtonStyle.outline => (Colors.white, HotziColors.ink, HotziColors.line),
    };
    final radius = BorderRadius.circular(16);
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: motion(context, const Duration(milliseconds: 120)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: enabled && widget.style == HotziButtonStyle.mango
              ? const [BoxShadow(color: Color(0x59FF8A3D), blurRadius: 20, offset: Offset(0, 8))]
              : null,
        ),
        child: Material(
          color: enabled ? background : HotziColors.line,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: border == null ? BorderSide.none : BorderSide(color: border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            child: SizedBox(
              height: widget.height,
              width: widget.expand ? double.infinity : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, size: 22, color: enabled ? foreground : HotziColors.ink2),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HotziText.body(
                          widget.fontSize,
                          weight: FontWeight.w800,
                          color: enabled ? foreground : HotziColors.ink2,
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
