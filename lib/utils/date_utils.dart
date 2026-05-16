/// 日期工具类
class DateUtils {
  DateUtils._();

  /// 格式化日期为中文格式：2026年5月8日
  static String formatChinese(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }

  /// 格式化日期为 ISO 格式：2026-05-08
  static String formatIso(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 格式化月份：5月
  static String formatMonth(DateTime date) {
    return '${date.month}月';
  }

  /// 计算已读天数
  static int elapsedDays(DateTime startDate) {
    return DateTime.now().difference(startDate).inDays;
  }

  /// 计算阅读周期
  static int readingCycleDays(DateTime start, DateTime end) {
    return end.difference(start).inDays;
  }

  /// 获取当前年份
  static int get currentYear => DateTime.now().year;

  /// 获取当前月份
  static int get currentMonth => DateTime.now().month;

  /// 获取当月第一天
  static DateTime get firstDayOfMonth =>
      DateTime(currentYear, currentMonth, 1);

  /// 获取当年第一天
  static DateTime get firstDayOfYear => DateTime(currentYear, 1, 1);
}
