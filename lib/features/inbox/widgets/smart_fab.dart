import 'package:flutter/material.dart';
import 'package:msgs/core/motion/motion_engine.dart';

class SmartFab extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onPressed;

  const SmartFab({
    super.key,
    required this.isExpanded,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: MotionEngine.durationFast,
      curve: MotionEngine.curveStandard,
      height: 56,
      width: isExpanded ? 150 : 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(isExpanded ? 16.0 : 28.0),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(isExpanded ? 16.0 : 28.0),
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.edit,
                color: theme.colorScheme.onPrimaryContainer,
              ),
              if (isExpanded) ...[
                const SizedBox(width: 8),
                Text(
                  'Start chat',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
