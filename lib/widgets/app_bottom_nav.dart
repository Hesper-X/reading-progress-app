import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// 底部导航栏（5 Tab）
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        top: 8,
        bottom: 8 + bottomPadding,
      ),
      child: Row(
        children: [
          _NavItem(
            icon: _HomeIcon(),
            label: '首页',
            isSelected: currentIndex == 0,
            onTap: () => onTap(0),
          ),
          _NavItem(
            icon: _LibraryIcon(),
            label: '书架',
            isSelected: currentIndex == 1,
            onTap: () => onTap(1),
          ),
          _NavItem(
            icon: _StatsIcon(),
            label: '统计',
            isSelected: currentIndex == 2,
            onTap: () => onTap(2),
          ),
          _NavItem(
            icon: _ShareIcon(),
            label: '分享',
            isSelected: currentIndex == 3,
            onTap: () => onTap(3),
          ),
          _NavItem(
            icon: _SettingsIcon(),
            label: '设置',
            isSelected: currentIndex == 4,
            onTap: () => onTap(4),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? AppColors.primary : AppColors.tabInactive;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: IconTheme(
                data: IconThemeData(color: color, size: 24),
                child: icon,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ 底部导航图标（内联 SVG/Icon 实现） ============

/// 首页 - 房子图标
class _HomeIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.home_outlined, color: IconTheme.of(context).color);
  }
}

/// 书架 - 书本图标
class _LibraryIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.menu_book_outlined, color: IconTheme.of(context).color);
  }
}

/// 统计 - 柱状图图标
class _StatsIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.bar_chart_outlined, color: IconTheme.of(context).color);
  }
}

/// 分享 - 分享图标
class _ShareIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.ios_share, color: IconTheme.of(context).color);
  }
}

/// 设置 - 齿轮图标
class _SettingsIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Icon(Icons.settings_outlined, color: IconTheme.of(context).color);
  }
}
