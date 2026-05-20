import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/books_provider.dart';
import '../services/reminder_scheduler.dart';
import '../services/notification_service.dart';
import '../providers/purchase_provider.dart';
import '../providers/books_provider.dart';
import '../repositories/book_repository.dart';
import '../databases/database_helper.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';
import '../widgets/celebration_overlay.dart';

/// 设置页 — 按设计稿 05 设置页.html 实现
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _goal = 50;
  bool _reminderEnabled = false;
  String _reminderTime = '21:00';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final settings = context.read<SettingsProvider>();
    _goal = settings.yearlyGoal;
    _reminderEnabled = settings.dailyReminder;
    _reminderTime = settings.reminderTime;
  }

  // ============ 年度目标弹窗 ============

  Future<void> _showGoalDialog() async {
    int tempGoal = _goal;
    final result = await showModalBottomSheet<int>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('年度目标',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  Text(
                    '${DateTime.now().year} 年',
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: tempGoal > 1
                            ? () => setModalState(() => tempGoal--)
                            : null,
                        iconSize: 36,
                      ),
                      Container(
                        width: 80,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$tempGoal',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: tempGoal < 500
                            ? () => setModalState(() => tempGoal++)
                            : null,
                        iconSize: 36,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: Color(0xFFDEE2E6)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          foregroundColor: const Color(0xFF868E96),
                        ),
                        child: const Text('取消', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, tempGoal),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('保存'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && result > 0 && mounted) {
      await context.read<SettingsProvider>().setYearlyGoal(result);
      await context.read<BooksProvider>().updateYearlyGoal(result);
      setState(() => _goal = result);

      // 降低目标后检测是否达标
      final provider = context.read<BooksProvider>();
      final isGoalMet = provider.currentYearCount >= result &&
          !provider.celebrationTriggered;
      if (isGoalMet && mounted) {
        provider.markCelebrationTriggered();
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('目标已更新')),
        );
      }
    }
  }

  // ============ 导出数据 ============

  Future<void> _showExportDialog() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('导出数据',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.code),
              title: const Text('JSON'),
              subtitle: const Text('完整数据，可编程读取'),
              onTap: () => Navigator.pop(ctx, 'json'),
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('CSV'),
              subtitle: const Text('Excel 可打开'),
              onTap: () => Navigator.pop(ctx, 'csv'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      await _exportData(result);
    }
  }

  Future<void> _exportData(String format) async {
    try {
      final repo = BookRepository(DatabaseHelper.instance);
      final books = await repo.getDoneBooks();

      String content;
      if (format == 'json') {
        content = '[\n';
        for (final book in books) {
          content +=
              '  {"title":"${book.title}","author":"${book.author ?? ""}",'
              '"read_date":"${book.formattedReadDate ?? ""}","rating":${book.rating ?? 0}},';
        }
        if (books.isNotEmpty) content = content.substring(0, content.length - 1);
        content += '\n]';
      } else {
        content = '书名,作者,读完日期,评分\n';
        for (final book in books) {
          content +=
              '${book.title},${book.author ?? ""},${book.formattedReadDate ?? ""},${book.rating ?? 0}\n';
        }
      }

      final tempDir = Directory.systemTemp.path;
      final file = File('$tempDir/reading_progress.$format');
      await file.writeAsString(content);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '读书进度条数据',
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败，请重试')),
        );
      }
    }
  }

  // ============ 提醒时间弹窗 ============

  Future<void> _showReminderDialog() async {
    String time = _reminderTime;
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('提醒时间',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              SizedBox(
                height: 160,
                child: CupertinoTimerPicker(
                  mode: CupertinoTimerPickerMode.hm,
                  initialTimerDuration: Duration(
                    hours: int.tryParse(time.split(':')[0]) ?? 21,
                    minutes: int.tryParse(time.split(':')[1]) ?? 0,
                  ),
                  onTimerDurationChanged: (duration) {
                    time =
                        '${duration.inHours.toString().padLeft(2, '0')}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}';
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, time),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      },
    );

    if (result != null && mounted) {
      await context.read<SettingsProvider>().setReminderTime(result);
      setState(() => _reminderTime = result);
      // 提醒时间变动后重新调度
      await ReminderScheduler().updateSchedule(
        booksProvider: context.read<BooksProvider>(),
        settingsProvider: context.read<SettingsProvider>(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('提醒已设置')),
        );
      }
    }
  }

  /// 导航到系统精确闹钟设置页（Android 12+）
  Future<void> _openExactAlarmSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.settings);
    } catch (_) {
      // 降级：打开应用详情设置
      if (Platform.isAndroid) {
        await AppSettings.openAppSettings();
      }
    }
  }

  // ============ 关于页 ============

  Future<void> _showAboutDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关于读书进度条'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('版本：${AppConstants.appVersion}'),
            const SizedBox(height: 8),
            const Text(AppConstants.slogan),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1),
        ),
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // === 年度目标 ===
          _Section(header: '年度目标', items: [
            _SettingCardData(
              icon: '📚',
              title: '年度读书目标',
              subtitle: '当前目标：$_goal 本',
              onTap: _showGoalDialog,
            ),
          ]),

          // === 数据管理 ===
          _Section(header: '数据管理', items: [
            _SettingCardData(
              icon: '📥',
              title: '导出数据 (JSON)',
              subtitle: '导出所有读书记录',
              onTap: () => _showExportDialog(),
            ),
            _SettingCardData(
              icon: '📥',
              title: '导出数据 (CSV)',
              subtitle: 'Excel 可读格式',
              onTap: () => _showExportDialog(),
            ),
            _SettingCardData(
              icon: '💾',
              title: '备份到本地',
              subtitle: '完整备份应用数据',
              showBorder: false,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('备份功能即将推出')),
                );
              },
            ),
          ]),

          // === 提醒设置 ===
          _Section(header: '提醒设置', items: [
            _SettingCardData.switchCard(
              icon: '🔔',
              title: '每日阅读提醒',
              subtitle: '有在读书籍时定向推送',
              subtitle2: '无在读书籍时不会打扰你',
              switchValue: _reminderEnabled,
              onSwitchChanged: (v) async {
                if (v) {
                  // 开启提醒前先申请通知权限（Android 13+）
                  await NotificationService().requestPermissions();
                }
                await context.read<SettingsProvider>().setDailyReminder(v);
                setState(() => _reminderEnabled = v);
                // 同步调度/取消每日提醒
                await ReminderScheduler().updateSchedule(
                  booksProvider: context.read<BooksProvider>(),
                  settingsProvider: context.read<SettingsProvider>(),
                );
              },
            ),
            _SettingCardData(
              icon: '🔔',
              title: '提醒时间',
              subtitle: _reminderTime,
              showBorder: false,
              showArrow: true,
              onTap: _reminderEnabled ? _showReminderDialog : null,
            ),
          ]),

          // === 法律与政策 ===
          _Section(header: '法律与政策', items: [
            _SettingCardData(
              icon: '📋',
              title: '用户协议',
              subtitle: '使用条款与服务说明',
              onTap: () => _showLegalDialog('用户协议', AppConstants.privacyLegalText),
            ),
            _SettingCardData(
              icon: '📜',
              title: '隐私政策',
              subtitle: '了解我们如何保护你的数据',
              onTap: () => _showLegalDialog('隐私政策', AppConstants.privacyPolicyText),
            ),
            _SettingCardData(
              icon: '🛡️',
              title: '个人信息收集清单',
              subtitle: '本 App 数据本地存储，不收集个人信息',
              onTap: () => _showLegalDialog('个人信息收集清单', AppConstants.privacyDataCollectionText),
            ),
            _SettingCardData(
              icon: '🔗',
              title: '第三方信息共享清单',
              subtitle: 'Flutter SDK 及第三方库清单',
              onTap: () => _showLegalDialog('第三方信息共享清单', AppConstants.privacyThirdPartyText),
            ),
            _SettingCardData(
              icon: '🔓',
              title: '开源许可',
              subtitle: '第三方库许可声明',
              showBorder: false,
              onTap: () => _showLegalDialog('开源许可', AppConstants.privacyOpenSourceText),
            ),
          ]),

          // === 关于 ===
          _Section(header: '关于', items: [
            _SettingCardData(
              icon: '📱',
              title: '版本',
              subtitle: AppConstants.appVersion,
              onTap: _showAboutDialog,
            ),
            _SettingCardData(
              icon: '💰',
              title: '恢复购买',
              subtitle: '已购买 Pro 功能',
              onTap: () async {
                final purchase = context.read<PurchaseProvider>();
                await purchase.setPro(true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('恢复成功')),
                  );
                }
              },
            ),
            _SettingCardData(
              icon: '⭐',
              title: '给个好评',
              subtitle: '支持我们继续改进',
              onTap: _rateApp,
            ),
            _SettingCardData(
              icon: '📧',
              title: '联系我们',
              subtitle: '问题反馈与建议',
              showBorder: false,
              onTap: _showContactDialog,
            ),
          ]),

          // === Footer ===
          const SizedBox(height: 16),
          const Center(
            child: Column(
              children: [
                Text(
                  '读书进度条 v${AppConstants.appVersion}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '把你读完的书，变成进度条',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _rateApp() {
    // TODO: iOS → App Store 评分页 URL
    // TODO: Android → Google Play / 应用商店评分页 URL
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('感谢你的支持！')),
    );
  }

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('联系我们'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('邮箱：${AppConstants.contactEmail}'),
            SizedBox(height: 8),
            Text('欢迎发送问题反馈、功能建议或合作意向，我们会在 48 小时内回复。'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: 调用系统邮件客户端
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('邮件功能即将上线')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('发送邮件'),
          ),
        ],
      ),
    );
  }

  void _showLegalDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(content, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

/// 设置项数据模型
class _SettingCardData {
  final String icon;
  final String title;
  final String subtitle;
  final String? subtitle2;
  final bool showBorder;
  final bool showArrow;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback? onTap;

  const _SettingCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.subtitle2,
    this.showBorder = true,
    this.showArrow = true,
    this.switchValue,
    this.onSwitchChanged,
    this.onTap,
  });

  const _SettingCardData.switchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtitle2,
    required this.switchValue,
    required this.onSwitchChanged,
    this.onTap,
  }) : showBorder = true,
       showArrow = false;
}

/// Section 容器：标题 + 卡片组（白色卡片容器包裹）
class _Section extends StatelessWidget {
  final String header;
  final List<_SettingCardData> items;

  const _Section({required this.header, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              header,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDEE2E6)),
            ),
            child: Column(
              children: items.asMap().entries.map((entry) {
                final i = entry.key;
                final item = entry.value;
                return _buildItem(item, isLast: i == items.length - 1);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_SettingCardData item, {required bool isLast}) {
    final showBottomBorder = item.showBorder && !isLast;

    return GestureDetector(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: showBottomBorder
              ? const Border(
                  bottom: BorderSide(color: Color(0xFFF1F3F5)),
                )
              : null,
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFE3E3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(item.icon, style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            // 文字信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    item.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (item.subtitle2 != null)
                    Text(
                      item.subtitle2!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            // 右侧：开关 或 箭头
            if (item.switchValue != null)
              _SwitchToggle(value: item.switchValue!, onChanged: item.onSwitchChanged)
            else if (item.showArrow)
              const Text(
                '›',
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

/// 开关组件（设计稿样式）
class _SwitchToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _SwitchToggle({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 28,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF51CF66) : const Color(0xFFDEE2E6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.all(2),
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
