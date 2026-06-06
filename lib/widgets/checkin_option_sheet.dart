import 'package:flutter/material.dart';
import '../theme/colors.dart';

/// 选择浮层（V3.5 变更十二）
/// 点击今日（已打卡）时弹出，提供「新增打卡」和「查看详情」两个选项
class CheckinOptionSheet extends StatelessWidget {
  final String dateStr;
  final VoidCallback onNewCheckin;
  final VoidCallback onViewDetail;

  const CheckinOptionSheet({
    super.key,
    required this.dateStr,
    required this.onNewCheckin,
    required this.onViewDetail,
  });

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${int.parse(parts[0])}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            '📅 ${_formatDate(dateStr)} · 已打卡',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // 为该日新增打卡
          _OptionButton(
            icon: '📖',
            label: '为该日新增打卡',
            onTap: onNewCheckin,
          ),
          const SizedBox(height: 8),

          // 查看今日打卡详情
          _OptionButton(
            icon: '📅',
            label: '查看今日打卡详情',
            onTap: onViewDetail,
          ),
        ],
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _OptionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
