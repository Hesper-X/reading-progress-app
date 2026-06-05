import 'package:flutter/foundation.dart';
import '../models/checkin.dart';
import '../repositories/checkin_repository.dart';
import '../repositories/book_repository.dart';

/// 打卡状态管理（V3.5）
/// 负责打卡日历数据、打卡对话框交互、多页联动
class CheckinProvider with ChangeNotifier {
  final CheckinRepository _repository;
  final BookRepository _bookRepository;

  // ============ 日历状态 ============

  int _currentYear;
  int _currentMonth;
  Set<String> _checkinDates = {}; // 当月所有打卡日期集合
  int _streakDays = 0; // 连续打卡天数（基于今天）
  bool _isLoading = false;
  String? _error;

  // ============ 当前 Dialog 状态 ============

  CheckinDetail? _lastCheckin; // 今日最后一次打卡记录（Dialog2 用来保留输入）

  CheckinProvider({
    required CheckinRepository repository,
    required BookRepository bookRepository,
  })  : _repository = repository,
        _bookRepository = bookRepository,
        _currentYear = DateTime.now().year,
        _currentMonth = DateTime.now().month;

  // ============ Getters ============

  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth;
  Set<String> get checkinDates => _checkinDates;
  int get streakDays => _streakDays;
  bool get isLoading => _isLoading;
  String? get error => _error;
  CheckinDetail? get lastCheckin => _lastCheckin;

  /// 今天是否有打卡
  bool get hasTodayCheckin {
    final today = _formatDate(DateTime.now());
    return _checkinDates.contains(today);
  }

  /// 格式化月份标签：如 "2026 年 6 月"
  String get monthLabel =>
      '$_currentYear 年 $_currentMonth 月';

  // ============ 日历数据加载 ============

  /// 加载指定年月的打卡数据
  Future<void> loadMonthCheckins({int? year, int? month}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final y = year ?? _currentYear;
      final m = month ?? _currentMonth;
      _currentYear = y;
      _currentMonth = m;

      _checkinDates = await _repository.getMonthCheckinDates(y, m);
      _streakDays = await _repository.getCurrentStreak();
      _lastCheckin = null;

      // 如果有今日打卡记录，加载最后一次用于 Dialog2 保留输入
      if (hasTodayCheckin) {
        final today = _formatDate(DateTime.now());
        final summary = await _repository.getDaySummary(today);
        if (summary.details.isNotEmpty) {
          _lastCheckin = summary.details.last;
        }
      }

      _isLoading = false;
      _error = null;
    } catch (e) {
      _isLoading = false;
      _error = '打卡数据加载失败';
      debugPrint('loadMonthCheckins error: $e');
    }

    notifyListeners();
  }

  /// 切换到上月
  Future<void> goToPrevMonth() async {
    if (_currentMonth == 1) {
      await loadMonthCheckins(year: _currentYear - 1, month: 12);
    } else {
      await loadMonthCheckins(month: _currentMonth - 1);
    }
  }

  /// 切换到下月
  Future<void> goToNextMonth() async {
    if (_currentMonth == 12) {
      await loadMonthCheckins(year: _currentYear + 1, month: 1);
    } else {
      await loadMonthCheckins(month: _currentMonth + 1);
    }
  }

  /// 刷新当月（打卡后调用）
  Future<void> refreshCurrentMonth() async {
    await loadMonthCheckins();
  }

  // ============ 打卡操作 ============

  /// 新建打卡
  /// 返回错误信息（成功返回 null）
  Future<String?> addCheckin({
    required int bookId,
    int? durationMin,
    String? note,
  }) async {
    try {
      final today = _formatDate(DateTime.now());
      final detail = CheckinDetail(
        bookId: bookId,
        checkinDate: today,
        durationMin: durationMin,
        note: note?.trim(),
      );

      await _repository.addCheckin(detail);
      await refreshCurrentMonth();
      return null; // 成功
    } catch (e) {
      debugPrint('addCheckin error: $e');
      return '打卡失败，请重试';
    }
  }

  /// 更新打卡（追加一条新记录，不修改原记录）
  Future<String?> updateCheckin({
    required int bookId,
    int? durationMin,
    String? note,
  }) async {
    try {
      final today = _formatDate(DateTime.now());
      final detail = CheckinDetail(
        bookId: bookId,
        checkinDate: today,
        durationMin: durationMin,
        note: note?.trim(),
      );

      await _repository.addCheckin(detail);
      await refreshCurrentMonth();
      return null; // 成功
    } catch (e) {
      debugPrint('updateCheckin error: $e');
      return '打卡失败，请重试';
    }
  }

  // ============ 查询 ============

  /// 获取某日的打卡摘要
  Future<CheckinDaySummary> getDaySummary(String date) async {
    return await _repository.getDaySummary(date);
  }

  /// 获取今天是否有打卡（用于 Dialog 触发判断）
  int? todayTotalMinutes;

  /// 获取书籍的打卡统计
  Future<Map<String, int>> getBookStats(int bookId) async {
    return await _repository.getBookCheckinStats(bookId);
  }

  /// 获取多本书的打卡统计
  Future<Map<int, Map<String, int>>> getBooksStats(List<int> bookIds) async {
    return await _repository.getBooksCheckinStats(bookIds);
  }

  // ============ 工具 ============

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
