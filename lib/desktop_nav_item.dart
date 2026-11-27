import 'package:flutter/material.dart';

class DesktopNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onSecondaryTap;

  const DesktopNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.onSecondaryTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = selected
        ? colors.onSecondaryContainer
        : colors.onSurfaceVariant;

    final child = Material(
      color: selected ? colors.secondaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 22, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: foreground,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: onSecondaryTap == null
          ? child
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTap: onSecondaryTap,
              child: child,
            ),
    );
  }
}
