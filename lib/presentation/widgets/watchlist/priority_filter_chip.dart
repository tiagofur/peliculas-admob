import 'package:flutter/material.dart';

class PriorityFilterChip extends StatelessWidget {
  const PriorityFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool isSelected;
  final void Function() onTap;
  final dynamic color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipColor = color ?? theme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey[400]!,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,

            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
