import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../providers/settings_provider.dart';
import 'notification_service.dart';

/// 每日阅读提醒调度器（基于 AlarmManager 持久调度）
///
/// 使用 flutter_local_notifications 的 zonedSchedule 实现
/// Android AlarmManager 级别的系统调度：
/// — App 被杀死后仍然有效
/// — 设备重启后失效（需要 RECEIVE_BOOT_COMPLETED 配合）
///
/// 提醒文案基于在读书籍动态生成「《XXX》还在读吗？」
/// 无在读书籍时静默跳过不推送。
class ReminderScheduler {
  static final ReminderScheduler _instance = ReminderScheduler._internal();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._internal();

  final NotificationService _notif = NotificationService();

  /// 通知 ID（每日固定，新通知自动覆盖旧通知）
  static const int _notificationId = 1001;

  /// 生成提醒正文
  /// - 有在读书籍 → 「《XXX》还在读吗？」
  /// - 无在读书籍 → null（不推送）
  String? _buildBody(List<Book>? readingBooks) {
    if (readingBooks != null && readingBooks.isNotEmpty) {
      return '《${readingBooks.first.title}》还在读吗？';
    }
    return null; // 无在读书籍不推送
  }

  /// 使用 schedule 实现持久每日定时（通过 AlarmManager）
  Future<void> _zonedSchedule(String nextBody) async {
    await _notif.init();

    // 确保时区数据已初始化（tz.TZDateTime.utc 需要）
    tz_data.initializeTimeZones();

    final settingsProvider = _lastSettings;
    if (settingsProvider == null) return;

    // 用本地 DateTime 计算目标时间，避免时区偏差
    final now = DateTime.now();
    final parts = settingsProvider.reminderTime.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now) || scheduledDate.isAtSameMomentAs(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    debugPrint('[Reminder] 持久调度: ${scheduledDate.toString()} (${settingsProvider.reminderTime}), ts=${scheduledDate.millisecondsSinceEpoch}');

    // 检测是否支持精确闹钟
    bool canScheduleExact = false;
    try {
      final androidPlugin = _notif.platform
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      canScheduleExact = await androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      canScheduleExact = false;
    }

    if (!canScheduleExact) {
      debugPrint('[Reminder] 精确闹钟权限未授权，将使用非精确模式（可能延迟）');
    }

    // 用 tz.local 时区构造 TZDateTime
    // 将本地时间转为 UTC 日历时间，然后构造 UTC 时区的 TZDateTime
    // 这样 millisecondsSinceEpoch 就是正确的 UTC 时间戳
    final utcDt = scheduledDate.toUtc();
    final utcDate = tz.TZDateTime.utc(utcDt.year, utcDt.month, utcDt.day, utcDt.hour, utcDt.minute);

    debugPrint('[Reminder] local: ${scheduledDate.toString()}, toUtc: ${utcDt.toString()}, tz_utc:${utcDate.toString()}, ms=${utcDate.millisecondsSinceEpoch}');

    await _notif.platform.zonedSchedule(
      _notificationId,
      '阅读提醒',
      nextBody,
      utcDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reading_reminder',
          '每日阅读提醒',
          channelDescription: '提醒你阅读在读书籍',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // 有精确闹钟权限用 exact，没有则用 inexactAllowWhileIdle 兜底
      androidScheduleMode: canScheduleExact
          ? AndroidScheduleMode.exact
          : AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 每日重复
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      // 设置 payload 以便通知点击时回调
      payload: 'reading_reminder',
    );
  }

  SettingsProvider? _lastSettings;
  List<Book>? _cachedReadingBooks;

  /// 更新提醒设置（由设置页调用）
  ///
  /// 调用时机：
  /// - 提醒开关变动
  /// - 提醒时间变动
  /// - 应用启动时
  ///
  /// 使用 Android AlarmManager 持久调度，App 被杀仍可触发。
  /// 同时同步写入 SharedPreferences 供 Native BootReceiver 开机恢复使用。
  Future<void> updateSchedule({
    required BooksProvider booksProvider,
    required SettingsProvider settingsProvider,
  }) async {
    _lastSettings = settingsProvider;
    _cachedReadingBooks = List.from(booksProvider.readingBooks);

    // 1. 同步设置到 SharedPreferences（供 Native BootReceiver 读取）
    await _syncToSharedPrefs(settingsProvider);

    // 2. 取消现有所有调度
    await _notif.cancelAll();

    // 3. 如果提醒关闭 → 不做任何调度
    if (!settingsProvider.dailyReminder) {
      debugPrint('[Reminder] 提醒已关闭，取消所有调度');
      return;
    }

    // 4. 生成提醒正文
    final body = _buildBody(booksProvider.readingBooks);
    if (body == null) {
      // 无在读书籍 → 不打扰，但不清除调度开关状态
      debugPrint('[Reminder] 无在读书籍，跳过调度');
      return;
    }

    // 5. 通过 zonedSchedule 持久调度（AlarmManager 级别）
    await _zonedSchedule(body);
  }

  /// 将提醒设置同步写入 SharedPreferences
  ///
  /// Native 侧 BootReceiver 从 SharedPreferences 读取设置
  /// 以在开机后恢复 AlarmManager 调度。
  Future<void> _syncToSharedPrefs(SettingsProvider settingsProvider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('flutter.daily_reminder', settingsProvider.dailyReminder);
      await prefs.setString('flutter.reminder_time', settingsProvider.reminderTime);
      debugPrint('[Reminder] 设置已同步到 SharedPreferences');
    } catch (e) {
      debugPrint('[Reminder] 同步到 SharedPreferences 失败: $e');
    }
  }

  /// 取消所有提醒调度
  Future<void> cancelAll() async {
    await _notif.cancelAll();
    debugPrint('[Reminder] 已取消所有调度');
  }

  /// 应用启动时恢复提醒调度
  Future<void> restoreAfterStartup({
    required BooksProvider booksProvider,
    required SettingsProvider settingsProvider,
  }) async {
    await _notif.init();
    if (settingsProvider.dailyReminder) {
      await updateSchedule(
        booksProvider: booksProvider,
        settingsProvider: settingsProvider,
      );
    }
  }
}
