import 'package:flutter/foundation.dart';
import '../repositories/settings_repository.dart';

/// 设置状态管理
class SettingsProvider with ChangeNotifier {
  final SettingsRepository _repository;

  int _yearlyGoal = 0;
  String _theme = 'light';
  bool _dailyReminder = false;
  String _reminderTime = '21:00';
  bool _proPurchased = false;
  bool _isLoading = false;

  SettingsProvider({required SettingsRepository repository})
      : _repository = repository;

  // ============ Getters ============

  int get yearlyGoal => _yearlyGoal;
  String get theme => _theme;
  bool get dailyReminder => _dailyReminder;
  String get reminderTime => _reminderTime;
  bool get proPurchased => _proPurchased;
  bool get isLoading => _isLoading;

  // ============ 加载 ============

  /// 加载所有设置
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      _yearlyGoal = await _repository.getYearlyGoal();
      _theme = await _repository.getTheme();
      _dailyReminder = await _repository.getDailyReminder();
      _reminderTime = await _repository.getReminderTime();
      _proPurchased = await _repository.isProPurchased();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ============ 操作 ============

  /// 更新年度目标
  Future<void> setYearlyGoal(int goal) async {
    await _repository.setYearlyGoal(goal);
    _yearlyGoal = goal;
    notifyListeners();
  }

  /// 更新主题
  Future<void> setTheme(String theme) async {
    await _repository.setTheme(theme);
    _theme = theme;
    notifyListeners();
  }

  /// 更新每日提醒开关
  Future<void> setDailyReminder(bool enabled) async {
    await _repository.setDailyReminder(enabled);
    _dailyReminder = enabled;
    notifyListeners();
  }

  /// 更新提醒时间
  Future<void> setReminderTime(String time) async {
    await _repository.setReminderTime(time);
    _reminderTime = time;
    notifyListeners();
  }

  /// 设置 Pro 购买状态
  Future<void> setProPurchased(bool purchased) async {
    await _repository.setProPurchased(purchased);
    _proPurchased = purchased;
    notifyListeners();
  }

  /// 恢复购买
  Future<void> restorePurchase() async {
    // 实际恢复逻辑在 PurchaseService 中处理
    // 这里只更新状态
    await setProPurchased(true);
  }
}
