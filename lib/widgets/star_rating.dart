import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 星级评分组件
class StarRating extends StatelessWidget {
  final int rating; // 0-5
  final ValueChanged<int>? onChanged;
  final double size;

  const StarRating({
    super.key,
    this.rating = 0,
    this.onChanged,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final isFilled = index < rating;
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(index + 1) : null,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              isFilled ? Icons.star : Icons.star_border,
              size: size,
              color: isFilled ? AppColors.starActive : AppColors.border,
            ),
          ),
        );
      }),
    );
  }
}
