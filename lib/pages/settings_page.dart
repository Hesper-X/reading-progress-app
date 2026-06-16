import 'dart:convert';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';
import 'package:app_settings/app_settings.dart';
import '../providers/settings_provider.dart';
import '../providers/books_provider.dart';
import '../providers/checkin_provider.dart';
import '../services/reminder_scheduler.dart';
import '../services/notification_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/purchase_provider.dart';
import '../repositories/book_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/checkin_repository.dart';
import '../models/checkin.dart';
import '../databases/database_helper.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';

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
  String? _purchaseStatus;
  bool _isRestoring = false;
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
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
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
                      SizedBox(
                        width: 100,
                        child: TextField(
                          controller: TextEditingController(text: '$tempGoal')
                            ..selection = TextSelection.collapsed(offset: '$tempGoal'.length),
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                              fontSize: 24, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null && parsed >= 1 && parsed <= 500) {
                              tempGoal = parsed;
                            }
                          },
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
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, tempGoal),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('保存'),
                      ),
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
                    ],
                  ),
                ],
              ),
            ),
            );
          },
        );
      },
    );

    if (result != null && result > 0 && mounted) {
      await context.read<SettingsProvider>().setYearlyGoal(result);
      context.read<BooksProvider>().resetCelebrationStatus();
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

  // ============ V3.4 导出数据 ============

  Future<void> _showExportSheet() async {
    final result = await showModalBottomSheet<bool>(
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
            const SizedBox(
              width: double.infinity,
              child: Text('📄  导出为 JSON 文件',
                  style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('确认'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFDEE2E6)),
                    foregroundColor: const Color(0xFF868E96),
                  ),
                  child: const Text('取消'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (result == true && mounted) {
      await _exportAllData();
    }
  }

  Future<void> _exportAllData() async {
    try {
      final db = DatabaseHelper.instance;
      final repo = BookRepository(db);
      final settingsRepo = SettingsRepository(db);
      final checkinRepo = CheckinRepository(db);

      // 获取所有书籍（不含已放弃）
      final allBooks = await repo.getAll();

      // 获取设置
      final settings = await settingsRepo.getAll();

      // V3.5: 获取打卡记录
      final allCheckins = await checkinRepo.getAllCheckins();

      // 获取年度目标
      final database = await db.database;
      final allYearGoals = await database.query('year_goals');

      // 构建导出 JSON
      final exportData = {
        'app': '读书进度条',
        'version': AppConstants.appVersion,
        'exportDate': DateTime.now().toIso8601String(),
        'books': allBooks.map((b) => {
          if (b.id != null) 'id': b.id,
          'type': b.status.value,
          'title': b.title,
          'author': b.author,
          if (b.coverPath != null) 'cover': _encodeCoverBase64(b.coverPath!),
          if (b.rating != null) 'rating': b.rating!,
          if (b.notes != null && b.notes!.isNotEmpty) 'review': b.notes!,
          if (b.readDate != null) 'finishDate': b.readDate!.toIso8601String(),
          'startDate': b.startDate.toIso8601String(),
          if (b.readCount > 1) 'readCount': b.readCount,
        }).toList(),
        'checkins': allCheckins.map((c) => c.toMap()).toList(),
        'yearGoals': allYearGoals,
        'settings': settings,
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(exportData);
      final file = File('${Directory.systemTemp.path}/reading_progress_export.json');
      await file.writeAsString(jsonStr);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '读书进度条数据导出',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败：$e')),
        );
      }
    }
  }

  /// 将封面图片编码为 base64
  String _encodeCoverBase64(String coverPath) {
    try {
      final file = File(coverPath);
      if (!file.existsSync()) return '';
      final bytes = file.readAsBytesSync();
      return base64Encode(bytes);
    } catch (_) {
      return '';
    }
  }

  // ============ V3.4 导入数据 ============

  Future<void> _importData() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'JSON',
        extensions: ['json'],
      );
      final result = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (result == null) return;

      final file = File(result.path);
      if (!await file.exists()) return;

      final content = await file.readAsString();
      final Map<String, dynamic> data;
      try {
        data = jsonDecode(content) as Map<String, dynamic>;
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件格式不正确，请选择本 App 导出的 JSON 文件')),
          );
        }
        return;
      }

      // 校验格式
      if (data['app'] != '读书进度条' ||
          data['version'] == null ||
          data['books'] == null ||
          data['books'] is! List) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件格式不正确，请选择本 App 导出的 JSON 文件')),
          );
        }
        return;
      }

      final booksList = data['books'] as List;
      if (booksList.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件中没有找到书籍记录')),
          );
        }
        return;
      }

      // 弹窗确认
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('导入数据'),
          content: Text('将导入 ${booksList.length} 本书籍记录${data['checkins'] != null ? '，${(data['checkins'] as List).length} 条打卡记录' : ''}，继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('确认导入'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;

      // 逐条导入（事务保护）
      final db = DatabaseHelper.instance;
      final database = await db.database;
      final booksProvider = context.read<BooksProvider>();

      // 先获取本地所有已有书籍 ID
      final localBooks = await database.query('books',
          columns: ['id'], where: "status != 'abandoned'");
      final localIds = localBooks.map((m) => m['id'] as int).toSet();

      int imported = 0;
      int skipped = 0;

      await database.transaction((txn) async {
        for (final item in booksList) {
          final itemMap = item as Map<String, dynamic>;
          final title = itemMap['title'] as String? ?? '';

          // 检查 ID 冲突
          final itemId = itemMap['id'] as int?;
          if (itemId != null && localIds.contains(itemId)) {
            skipped++;
            continue;
          }

          // 解码 base64 封面
          String? savedCoverPath;
          final base64Cover = itemMap['cover'] as String?;
          if (base64Cover != null && base64Cover.isNotEmpty) {
            try {
              final bytes = base64Decode(base64Cover);
              final appDir = await getApplicationDocumentsDirectory();
              final coversDir = Directory('${appDir.path}/covers');
              if (!await coversDir.exists()) {
                await coversDir.create(recursive: true);
              }
              final destPath = '${coversDir.path}/import_${DateTime.now().millisecondsSinceEpoch}_${imported}.jpg';
              await File(destPath).writeAsBytes(bytes);
              savedCoverPath = destPath;
            } catch (_) {}
          }

          final type = itemMap['type'] as String? ?? 'done';
          final startDateStr = itemMap['startDate'] as String?;
          final finishDateStr = itemMap['finishDate'] as String?;
          final rating = itemMap['rating'] as num?;

          await txn.insert('books', {
            'title': title,
            'author': itemMap['author'] as String? ?? '',
            if (savedCoverPath != null) 'cover_path': savedCoverPath,
            if (rating != null) 'rating': (rating * 10).round(),
            if (itemMap['review'] != null) 'notes': itemMap['review'] as String,
            if (finishDateStr != null) 'read_date': finishDateStr,
            'start_date': startDateStr ?? DateTime.now().toIso8601String(),
            'status': type,
            'read_count': (itemMap['readCount'] as int?) ?? 1,
            'created_at': DateTime.now().toIso8601String(),
          });
          imported++;
        }
      });

      // 导入打卡记录
      final importedCheckins = data['checkins'] as List?;
      if (importedCheckins != null && importedCheckins.isNotEmpty) {
        final checkinRepo = CheckinRepository(db);
        for (final item in importedCheckins) {
          final checkinMap = item as Map<String, dynamic>;
          if (checkinMap['book_id'] != null) {
            await checkinRepo.addCheckin(CheckinDetail.fromMap(checkinMap));
          }
        }
      }

      // 导入年度目标
      final importedYearGoals = data['yearGoals'] as List?;
      if (importedYearGoals != null && importedYearGoals.isNotEmpty) {
        for (final item in importedYearGoals) {
          final goalMap = item as Map<String, dynamic>;
          await database.insert(
            'year_goals',
            goalMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // 刷新数据
      await booksProvider.loadBooks();
      // V3.5 fix: 导入后同步刷新打卡数据和年度目标
      context.read<CheckinProvider>().loadMonthCheckins();
      context.read<SettingsProvider>().loadSettings();

      if (mounted) {
        final checkinCount = importedCheckins?.length ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入成功！已恢复 $imported 本书籍记录${skipped > 0 ? '，跳过 $skipped 条重复记录' : ''}，$checkinCount 条打卡记录')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败：$e')),
        );
      }
    }
  }

  // ============ V3.4 清空数据 ============

  Future<void> _showClearDataDialog() async {
    // 第一次确认
    final firstConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清空所有数据？'),
        content: const Text('此操作不可恢复，所有书籍记录和设置将被删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              side: const BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              foregroundColor: const Color(0xFF868E96),
            ),
            child: const Text('取消', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            child: const Text('继续', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (firstConfirmed != true || !mounted) return;

    // 第二次确认：输入文本
    final secondConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String inputText = '';
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('输入「确认删除」继续'),
            content: TextField(
              onChanged: (v) => setDialogState(() => inputText = v),
              decoration: InputDecoration(
                hintText: '确认删除',
                hintStyle: const TextStyle(color: Color(0xFFADB5BD)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: TextButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFDEE2E6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  foregroundColor: const Color(0xFF868E96),
                ),
                child: const Text('取消', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (inputText == '确认删除') {
                    Navigator.pop(ctx, true);
                  } else {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('请输入准确文字')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                ),
                child: const Text('确认', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        );
      },
    );

    if (secondConfirmed != true || !mounted) return;

    // 执行清空
    await _executeClearData();
  }

  Future<void> _executeClearData() async {
    try {
      final db = DatabaseHelper.instance;
      final database = await db.database;

      // 清空 books 表
      await database.delete('books');
      // V3.5 fix: 同时清空打卡记录
      await database.delete('checkin_details');
      // 重置设置
      await database.delete('settings', where: "key NOT IN ('pro_purchased')");

      // 重新插入默认设置
      await database.insert('settings', {'key': 'yearly_goal', 'value': '0'});
      await database.insert('settings', {'key': 'theme', 'value': 'light'});
      await database.insert('settings', {'key': 'daily_reminder', 'value': 'false'});
      await database.insert('settings', {'key': 'reminder_time', 'value': '21:00'});
      await database.insert('settings', {'key': 'backup_enabled', 'value': 'false'});

      // 刷新 Provider 数据
      final booksProvider = context.read<BooksProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      await booksProvider.loadBooks();
      await settingsProvider.loadSettings();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('数据已清空')),
        );

        // 重启首页
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('清空失败：$e')),
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
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: int.tryParse(time.split(':')[0]) ?? 21,
                        ),
                        itemExtent: 32,
                        onSelectedItemChanged: (i) {
                          final h = i.toString().padLeft(2, '0');
                          final m = time.split(':')[1];
                          time = '$h:$m';
                        },
                        children: List.generate(24, (i) =>
                          Center(child: Text(i.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20)))),
                      ),
                    ),
                    const Center(child: Text('时', style: TextStyle(fontSize: 20))),
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: int.tryParse(time.split(':')[1]) ?? 0,
                        ),
                        itemExtent: 32,
                        onSelectedItemChanged: (i) {
                          final h = time.split(':')[0];
                          final m = i.toString().padLeft(2, '0');
                          time = '$h:$m';
                        },
                        children: List.generate(60, (i) =>
                          Center(child: Text(i.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 20)))),
                      ),
                    ),
                    const Center(child: Text('分', style: TextStyle(fontSize: 20))),
                  ],
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

      // Android 12+：引导用户授权精确闹钟，确保提醒准时
      // 精确闹钟权限在 Android 12+ 需要用户手动在系统设置中开启
      // 此处弹窗引导用户跳转到系统设置
      if (Platform.isAndroid && mounted) {
        final sdkVersion = int.tryParse(Platform.version.split(' ').first) ?? 0;
        if (sdkVersion >= 31) { // Android 12+ (API 31)
          final shouldOpen = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('确保提醒准时触发'),
              content: const Text('请允许「Reading Progress」使用精确闹钟权限，以确保每日提醒准时送达。'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('暂不设置'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('去设置'),
                ),
              ],
            ),
          );
          if (shouldOpen == true && mounted) {
            await AppSettings.openAppSettings(type: AppSettingsType.settings);
          }
        }
      }
    }
  }

  /// 检测精确闹钟权限，未开启时弹系统原生请求
  /// 返回 true 表示已拥有精确闹钟权限；false 表示用户未授予
  Future<bool> _requestExactAlarmPermissionIfNeeded() async {
    try {
      final androidPlugin = NotificationService().platform
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin == null) return false;

      final canSchedule = await androidPlugin.canScheduleExactNotifications();
      if (canSchedule != true) {
        // 弹出系统原生精确闹钟权限请求
        await androidPlugin.requestExactAlarmsPermission();

        // 重新检测（用户刚点了 Allow/Deny）
        final retry = await androidPlugin.canScheduleExactNotifications();
        return retry == true;
      }
      return true; // 已有权限
    } catch (_) {
      // 低版本 Android 或异常情况，返回 false
      return false;
    }
  }

  /// 显示权限被拒提示
  void _showPermissionDeniedSnackbar(String permissionName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$permissionName权限被拒绝，提醒功能无法正常工作。请在系统设置中手动开启该权限。'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: '去设置',
          onPressed: () {
            try {
              AppSettings.openAppSettings(type: AppSettingsType.notification);
            } catch (_) {
              // 无法跳转时忽略
            }
          },
        ),
      ),
    );
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

          // === 数据管理（V3.4 重构：导出/导入/清空） ===
          _Section(header: '数据管理', items: [
            _SettingCardData(
              icon: '📥',
              title: '导出数据',
              subtitle: '导出为 JSON 文件',
              onTap: _showExportSheet,
            ),
            _SettingCardData(
              icon: '📤',
              title: '导入数据',
              subtitle: '从 JSON 文件恢复数据',
              onTap: _importData,
            ),
            _SettingCardData(
              icon: '⚠️',
              title: '清空数据',
              subtitle: '清除所有书籍记录和设置',
              showBorder: false,
              onTap: _showClearDataDialog,
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
                  final notifGranted = await NotificationService().requestPermissions();

                  // 如果用户拒绝了通知权限，不打开开关
                  if (notifGranted != true) {
                    _showPermissionDeniedSnackbar('通知');
                    setState(() => _reminderEnabled = false);
                    return;
                  }

                  // Android 12+：检测并引导精确闹钟权限
                  if (mounted) {
                    final alarmGranted = await _requestExactAlarmPermissionIfNeeded();
                    if (!alarmGranted) {
                      // 精确闹钟权限被拒，提醒可关闭通知但闹钟可能不准时
                      // 仍允许用户继续使用，因为通知仍然能发
                    }
                  }
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
              onTap: _restorePurchase,
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

  /// 恢复购买（IAP 校验 + 加载状态）
  Future<void> _restorePurchase() async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
      _purchaseStatus = '正在恢复...';
    });

    try {
      // Mock IAP 恢复（待 IAP 商品 ID 到位后替换为真实实现）
      await Future.delayed(const Duration(seconds: 1));
      final purchase = context.read<PurchaseProvider>();
      await purchase.setPro(true);
      final isPro = purchase.isPro;

      if (!mounted) return;
      if (isPro) {
        setState(() => _purchaseStatus = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已恢复 Pro 权益')),
        );
      } else {
        setState(() => _purchaseStatus = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未找到购买记录')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _purchaseStatus = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('恢复失败，请重试')),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  void _rateApp() async {
    // iOS: App Store 评分页
    if (Platform.isIOS) {
      // 使用 App Store 完整 URL（包含 appId 占位）
      const appStoreUrl = 'https://apps.apple.com/app/读书进度条/id0000000000?action=write-review';
      if (await canLaunchUrl(Uri.parse(appStoreUrl))) {
        await launchUrl(Uri.parse(appStoreUrl), mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Android / HarmonyOS: 应用市场详情页
    // 尝试华为应用市场
    const huaweiUrl = 'appmarket://details?id=com.hespe.reading_progress';
    if (await canLaunchUrl(Uri.parse(huaweiUrl))) {
      await launchUrl(Uri.parse(huaweiUrl), mode: LaunchMode.externalApplication);
      return;
    }

    // 尝试 Google Play
    const playUrl = 'market://details?id=com.hespe.reading_progress';
    if (await canLaunchUrl(Uri.parse(playUrl))) {
      await launchUrl(Uri.parse(playUrl), mode: LaunchMode.externalApplication);
      return;
    }

    // 兜底：引导弹窗
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('支持我们'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('如果喜欢这个 App，请在'),
            Text('App Store / 应用市场'),
            Text('给我们 5 星好评 ⭐⭐⭐⭐⭐'),
            SizedBox(height: 8),
            Text('搜索「读书进度条」即可'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() async {
    // 尝试调起系统邮件客户端
    final mailtoUri = Uri(
      scheme: 'mailto',
      path: AppConstants.contactEmail,
      queryParameters: {'subject': '读书进度条 - 用户反馈'},
    );
    if (await canLaunchUrl(mailtoUri)) {
      await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      return;
    }

    // 兜底：复制邮箱到剪贴板
    if (!mounted) return;
    await Clipboard.setData(ClipboardData(text: AppConstants.contactEmail));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('邮箱地址已复制')),
    );
  }

  /// V3.4 方式：直接以 AlertDialog 显示纯文本内容，不依赖 html 解析
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

/// 简单的法律文档 HTML 渲染组件（不依赖 WebView）
class _LegalHtmlBody extends StatelessWidget {
  final String html;
  const _LegalHtmlBody({required this.html});

  @override
  Widget build(BuildContext context) {
    final content = _parseHtml(html);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: content,
      ),
    );
  }

  List<Widget> _parseHtml(String html) {
    final widgets = <Widget>[];
    final lines = html
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .split('\n');

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('<h1>')) {
        final text = trimmed.replaceAll(RegExp(r'<[^>]+>'), '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF212529))),
        ));
      } else if (trimmed.startsWith('<h2>')) {
        final text = trimmed.replaceAll(RegExp(r'<[^>]+>'), '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF212529))),
        ));
      } else if (trimmed == '<hr>' || trimmed == '<hr/>' || trimmed == '<hr />') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Color(0xFFDEE2E6), height: 1),
        ));
      } else if (trimmed.startsWith('<table')) {
        // skip, in table
      } else if (trimmed == '</table>') {
        // skip
      } else if (trimmed.startsWith('<tr>')) {
        final cells = trimmed
            .replaceAll(RegExp(r'<t[hd][^>]*>'), '|')
            .replaceAll(RegExp(r'</t[hd]>'), '|')
            .split('|')
            .where((s) => s.trim().isNotEmpty)
            .map((s) => s.replaceAll(RegExp(r'<[^>]+>'), '').trim())
            .toList();
        if (cells.isNotEmpty) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(cells.join('  |  '), style: const TextStyle(fontSize: 12, height: 1.5)),
          ));
        }
      } else if (trimmed.startsWith('<ul>') || trimmed == '<ul>') {
        // skip
      } else if (trimmed == '</ul>') {
        // skip
      } else if (trimmed.startsWith('<li>')) {
        final text = trimmed.replaceAll(RegExp(r'<[^>]+>'), '');
        widgets.add(Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('\u2022 ', style: TextStyle(fontSize: 14, color: Color(0xFF333))),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF333), height: 1.6))),
          ]),
        ));
      } else if (trimmed.startsWith('<p')) {
        final text = trimmed.replaceAll(RegExp(r'<[^>]+>'), '');
        if (text.isNotEmpty) {
          widgets.add(Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF333), height: 1.8)),
          ));
        }
      } else if (trimmed.startsWith('<div class="lib"')) {
        final inner = trimmed
            .replaceAll(RegExp(r'<div[^>]*>'), '')
            .replaceAll('</div>', '')
            .replaceAll(RegExp(r'<p[^>]*>|</p>'), '')
            .replaceAll(RegExp(r'<br\s*/?>'), '\n')
            .replaceAll(RegExp(r'<strong>|</strong>|<a[^>]+>|</a>'), '');
        widgets.add(Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(inner.trim(), style: const TextStyle(fontSize: 13, color: Color(0xFF495057), height: 1.6)),
        ));
      } else if (trimmed.startsWith('</html>') || trimmed.startsWith('</body>')) {
        // skip
      }
    }
    return widgets;
  }
}
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
