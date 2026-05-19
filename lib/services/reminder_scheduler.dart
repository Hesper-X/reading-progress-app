import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../providers/settings_provider.dart';
import 'notification_service.dart';

/// 每日阅读提醒调度器
///
/// 职责：
/// 1. 根据设置的时间，计算下次提醒的延迟时长
/// 2. 使用 Timer 实现每日定时通知（Flutter 前台运行）
/// 3. Android 后台持久调度通过 flutter_local_notifications 的
///    periodicallyShow 或 android_alarm_manager 实现
///
/// 简化方案：应用在前台+后台存活时使用 Timer 触发；
/// 应用被杀后 Android 系统通过 pending intent 恢复。
class ReminderScheduler {
  static final ReminderScheduler _instance = ReminderScheduler._internal();
  factory ReminderScheduler() => _instance;
  ReminderScheduler._internal();

  final NotificationService _notif = NotificationService();
  Timer? _dailyTimer;
  bool _scheduled = false;

  /// 计算从当前时间到目标时间的延迟（毫秒）
  /// 如果目标时间已过，则安排到明天同一时间
  Duration _computeDelay(String timeStr) {
    final parts = timeStr.split(':');
    final targetHour = int.parse(parts[0]);
    final targetMinute = int.parse(parts[1]);

    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, targetHour, targetMinute);

    if (next.isBefore(now) || next.isAtSameMomentAs(now)) {
      next = next.add(const Duration(days: 1));
    }

    return next.difference(now);
  }

  /// 缓存当前在读书籍列表（由 updateSchedule 调用时设置）
  List<Book>? _cachedReadingBooks;

  void cacheReadingBooks(List<Book> books) {
    _cachedReadingBooks = books;
  }

  String _buildFallbackBody() {
    if (_cachedReadingBooks != null && _cachedReadingBooks!.isNotEmpty) {
      final title = _cachedReadingBooks!.first.title;
      return '《$title》还在读吗？';
    }
    return '今天读书了吗？';
  }

  /// 执行提醒（由 Timer 触发）
  Future<void> _executeReminder() async {
    final body = _buildFallbackBody();
    // 只在有在读书籍时推送
    if (_cachedReadingBooks != null && _cachedReadingBooks!.isNotEmpty) {
      await _notif.showNotification(
        title: '阅读提醒',
        body: body,
      );
    }
    // 无在读书籍时静默跳过，不推送

    // 安排明天的提醒
    _scheduleNext();
  }

  /// 安排下一次提醒
  void _scheduleNext() {
    _dailyTimer?.cancel();

    final settingsProvider = _lastSettings;
    if (settingsProvider == null || !settingsProvider.dailyReminder) {
      return;
    }

    final delay = _computeDelay(settingsProvider.reminderTime);
    debugPrint('[Reminder] 下次提醒延迟: ${delay.inMinutes} 分钟');

    _dailyTimer = Timer(delay, _executeReminder);
    _scheduled = true;
  }

  SettingsProvider? _lastSettings;

  /// 更新提醒设置（由设置页调用）
  ///
  /// 当用户开关提醒/修改时间时调用此方法，
  /// 重新计算下次提醒时间并调度。
  Future<void> updateSchedule({
    required BooksProvider booksProvider,
    required SettingsProvider settingsProvider,
  }) async {
    _lastSettings = settingsProvider;

    // 缓存当前在读书籍
    cacheReadingBooks(booksProvider.readingBooks);

    // 取消现有调度
    _dailyTimer?.cancel();
    _scheduled = false;

    if (!settingsProvider.dailyReminder) {
      // 提醒已关闭，取消所有通知
      await _notif.cancelAll();
      debugPrint('[Reminder] 提醒已关闭，取消所有通知');
      return;
    }

    // 有在读书籍才安排提醒
    if (booksProvider.readingBooks.isEmpty) {
      debugPrint('[Reminder] 无在读书籍，不安排提醒');
      return;
    }

    // 初始化通知服务
    await _notif.init();

    final delay = _computeDelay(settingsProvider.reminderTime);
    debugPrint('[Reminder] 安排提醒，延迟: ${delay.inMinutes} 分钟');

    _dailyTimer = Timer(delay, _executeReminder);
    _scheduled = true;
  }

  /// 取消所有调度和通知
  Future<void> cancelAll() async {
    _dailyTimer?.cancel();
    _scheduled = false;
    await _notif.cancelAll();
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

  bool get isScheduled => _scheduled;
}
