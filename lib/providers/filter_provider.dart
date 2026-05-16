import 'package:flutter/foundation.dart';
import '../models/filter_state.dart';
import '../repositories/book_repository.dart';
import '../repositories/settings_repository.dart';

/// 筛选状态管理（V3.0 新增 — 统计页 & 分享页共享）
class FilterProvider with ChangeNotifier {
  final BookRepository _bookRepository;
  final SettingsRepository _settingsRepository;

  FilterState _state = FilterState();
  List<int> _availableYears = [];

  FilterProvider({
    required BookRepository bookRepository,
    required SettingsRepository settingsRepository,
  })  : _bookRepository = bookRepository,
        _settingsRepository = settingsRepository;

  // ============ Getters ============

  FilterState get state => _state;
  List<int> get availableYears => _availableYears;
  int? get selectedYear => _state.selectedYear;
  int? get selectedMonth => _state.selectedMonth;
  bool get isPro => _state.isPro;
  bool get showProgressRing => _state.showProgressRing;
  String get dynamicTitle => _state.dynamicTitle;

  // ============ 初始化 ============

  /// 加载初始数据
  Future<void> loadInitial() async {
    final isPurchased = await _settingsRepository.isProPurchased();
    final availableYears = await _bookRepository.getAvailableYears();

    _state = FilterState(
      selectedYear: DateTime.now().year, // 首次默认当年
      selectedMonth: null,
      isPro: isPurchased,
    );
    _availableYears = availableYears;
    notifyListeners();
  }

  // ============ 操作 ============

  /// 设置年份筛选
  void setYear(int? year) {
    _state.selectedYear = year;
    notifyListeners();
  }

  /// 设置月份筛选
  void setMonth(int? month) {
    _state.selectedMonth = month;
    notifyListeners();
  }

  /// 重置筛选到默认
  void resetToDefault() {
    _state = FilterState(
      selectedYear: DateTime.now().year,
      selectedMonth: null,
      isPro: _state.isPro,
    );
    notifyListeners();
  }

  /// 锁定为当年+无月份（首页庆祝跳转时调用）
  void lockToCurrentYear() {
    _state.selectedYear = DateTime.now().year;
    _state.selectedMonth = null;
    notifyListeners();
  }

  /// 切换到全部生涯模式（Pro「我的阅读生涯」按钮）
  void switchToAllYears() {
    if (_state.isPro) {
      _state.selectedYear = null;
      _state.selectedMonth = null;
      notifyListeners();
    }
  }

  /// 更新 Pro 状态
  void updateProStatus(bool isPro) {
    _state.isPro = isPro;
    notifyListeners();
  }

  /// 刷新可选年份列表
  Future<void> refreshAvailableYears() async {
    _availableYears = await _bookRepository.getAvailableYears();
    notifyListeners();
  }

  /// 获取某年的月度趋势
  Future<Map<int, int>> getMonthlyTrend(int year) async {
    return await _bookRepository.getMonthlyTrend(year);
  }

  /// 获取年度对比（Pro）
  Future<List<Map<String, dynamic>>> getYearlyComparison() async {
    return await _bookRepository.getYearlyComparison();
  }
}
