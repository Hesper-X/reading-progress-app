import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 每日阅读提醒通知服务
///
/// 基于在读书籍动态生成提醒文案，每日指定时间推送。
/// 无在读书籍时不触发（由调用方控制）。
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 通知渠道配置常量
  static const String _channelId = 'daily_reading_reminder';
  static const String _channelName = '每日阅读提醒';
  static const String _channelDesc = '提醒你阅读在读书籍';

  /// 通知 ID（固定 ID 实现每日覆盖）
  static const int _notificationId = 1001;

  /// 初始化通知插件
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// 创建/更新通知渠道（Android 8.0+ 必需）
  Future<void> _ensureChannel() async {
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// 显示本地通知
  ///
  /// [title] 通知标题，如「阅读提醒」
  /// [body] 通知正文，如「《三体》还在读吗？」
  Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    await _ensureChannel();

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      // Android 12+ 弹窗通知（需 POST_NOTIFICATIONS 权限）
      fullScreenIntent: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      _notificationId,
      title,
      body,
      details,
    );
  }

  /// 取消所有通知
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  /// 取消指定通知
  Future<void> cancel(int id) async {
    await _plugin.cancel(id);
  }

  /// 请求 Android 13+ 通知权限
  Future<bool> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return false;

    final granted = await androidPlugin.requestNotificationsPermission();
    return granted ?? false;
  }
}
