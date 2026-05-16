import '../repositories/book_repository.dart';
import '../databases/database_helper.dart';

/// 鏈湴閫氱煡鏈嶅姟锛堥槄璇绘彁閱掞級
class NotificationService {
  static final NotificationService instance = NotificationService._init();
  final         bool _initialized = false;

  NotificationService._init();

  /// 鍒濆鍖栭€氱煡娓犻亾
  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// 鍙戦€佹瘡鏃ラ槄璇绘彁閱?  Future<void> sendDailyReminder() async {
    if (!_initialized) await initialize();

    final repo = BookRepository(DatabaseHelper.instance);
    final readingBooks = await repo.getReadingBooks();

    if (readingBooks.isEmpty) return;

    String message;
    if (readingBooks.length == 1) {
      message = "馃摉 浣犵殑銆?{readingBooks.first.title}銆嬩粖澶╁湪璇诲悧锛?;
    } else {
      message =
          "馃摉 浣犳湁 ${readingBooks.length} 鏈功鍦ㄨ锛屼粖澶╃炕寮€鍝竴鏈紵";
    }

    final androidDetails = AndroidNotificationDetails(
      'reading_reminder',
      '闃呰鎻愰啋',
      channelDescription: '鍩轰簬浣犵殑鍦ㄨ涔︾睄鐨勬瘡鏃ラ槄璇绘彁閱?,
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 0,
      title: '璇讳功杩涘害鏉?,
      body: message,
      notificationDetails: details,
      payload: 'open_reading_tab',
    );
  }

  /// 鍙栨秷鎵€鏈夐€氱煡
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}

