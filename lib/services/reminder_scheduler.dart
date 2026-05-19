import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  bool _tzInitialized = false;

  /// 通知 ID（每日固定，新通知自动覆盖旧通知）
  static const int _notificationId = 1001;

  /// 初始化时区数据（只需一次）
  void _ensureTz() {
    if (!_tzInitialized) {
      tz_data.initializeTimeZones();
      _tzInitialized = true;
    }
  }

  /// 生成提醒正文
  /// - 有在读书籍 → 「《XXX》还在读吗？」
  /// - 无在读书籍 → null（不推送）
  String? _buildBody(List<Book>? readingBooks) {
    if (readingBooks != null && readingBooks.isNotEmpty) {
      return '《${readingBooks.first.title}》还在读吗？';
    }
    return null; // 无在读书籍不推送
  }

  /// 计算今日目标时间（本地时区）
  /// 如果已过则返回明天的同一时间
  tz.TZDateTime _nextReminderTime(String timeStr) {
    _ensureTz();
    final local = tz.local;
    final parts = timeStr.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);

    final now = tz.TZDateTime.now(local);
    var scheduled = tz.TZDateTime(local, now.year, now.month, now.day, hour, minute);

    if (scheduled.isBefore(now) || scheduled.isAtSameMomentAs(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  /// 通过 Android AlarmManager 调度每日提醒
  ///
  /// 使用 [zonedSchedule] 设置一次性提醒，配合 [matchDateTimeComponents]
  /// 参数 [DateTimeComponents.time] 实现每日重复。
  /// 这是系统级调度，App 被杀死后依然触发。
  Future<void> _scheduleAlarm(String nextBody) async {
    await _notif.init();
    _ensureTz();

    final settingsProvider = _lastSettings;
    if (settingsProvider == null) return;

    final scheduledDate = _nextReminderTime(settingsProvider.reminderTime);

    await _notif.platform.show(
      _notificationId,
      '阅读提醒',
      nextBody,
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
      payload: 'reading_reminder',
    );
  }

  /// 通过 zonedSchedule 实现持久每日定时
  Future<void> _zonedSchedule(String nextBody) async {
    await _notif.init();
    _ensureTz();

    final settingsProvider = _lastSettings;
    if (settingsProvider == null) return;

    final scheduledDate = _nextReminderTime(settingsProvider.reminderTime);

    debugPrint('[Reminder] 持久调度: ${scheduledDate.toString()} (${settingsProvider.reminderTime})');

    await _notif.platform.zonedSchedule(
      _notificationId,
      '阅读提醒',
      nextBody,
      scheduledDate,
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
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
  Future<void> updateSchedule({
    required BooksProvider booksProvider,
    required SettingsProvider settingsProvider,
  }) async {
    _lastSettings = settingsProvider;
    _cachedReadingBooks = List.from(booksProvider.readingBooks);

    // 1. 取消现有所有调度
    await _notif.cancelAll();

    // 2. 如果提醒关闭 → 不做任何调度
    if (!settingsProvider.dailyReminder) {
      debugPrint('[Reminder] 提醒已关闭，取消所有调度');
      return;
    }

    // 3. 生成提醒正文
    final body = _buildBody(booksProvider.readingBooks);
    if (body == null) {
      // 无在读书籍 → 不打扰，但不清除调度开关状态
      debugPrint('[Reminder] 无在读书籍，跳过调度');
      return;
    }

    // 4. 通过 zonedSchedule 持久调度（AlarmManager 级别）
    await _zonedSchedule(body);
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
