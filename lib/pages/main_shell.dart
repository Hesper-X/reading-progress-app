import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/filter_provider.dart';
import '../widgets/app_bottom_nav.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'stats_page.dart';
import 'share_page.dart';
import 'settings_page.dart';

/// 主页框架页（承载底部 5 Tab 导航）
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    _HomePagePlaceholder(),
    _LibraryPagePlaceholder(),
    _StatsPagePlaceholder(),
    _SharePagePlaceholder(),
    _SettingsPagePlaceholder(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentIndex != 0) {
          // 非首页 → 切回首页
          setState(() => _currentIndex = 0);
        } else {
          // 首页 → 退出 App
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _currentIndex,
          onTap: (index) {
            // V3.4: 切换到分享页时重置 fromReadingLife 模式
            if (index == 3) {
              context.read<FilterProvider>().setFromReadingLife(false);
            }
            setState(() => _currentIndex = index);
          },
        ),
      ),
    );
  }
}

class _HomePagePlaceholder extends StatelessWidget {
  const _HomePagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const HomePage();
  }
}

class _LibraryPagePlaceholder extends StatelessWidget {
  const _LibraryPagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return LibraryPage();
  }
}

class _StatsPagePlaceholder extends StatelessWidget {
  const _StatsPagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const StatsPage();
  }
}

class _SharePagePlaceholder extends StatelessWidget {
  const _SharePagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SharePage();
  }
}

class _SettingsPagePlaceholder extends StatelessWidget {
  const _SettingsPagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SettingsPage();
  }
}
