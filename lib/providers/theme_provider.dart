import 'package:flutter/foundation.dart';
import '../repositories/settings_repository.dart';

/// 主题状态管理
class ThemeProvider with ChangeNotifier {
  final SettingsRepository _repository;

  String _theme = 'light';

  ThemeProvider({required SettingsRepository repository})
      : _repository = repository;

  String get theme => _theme;

  /// 是否为深色主题
  bool get isDark => _theme == 'dark';

  /// 加载主题
  Future<void> loadTheme() async {
    _theme = await _repository.getTheme();
    notifyListeners();
  }

  /// 切换主题
  Future<void> toggleTheme() async {
    final newTheme = _theme == 'light' ? 'dark' : 'light';
    await _repository.setTheme(newTheme);
    _theme = newTheme;
    notifyListeners();
  }

  /// 设置主题
  Future<void> setTheme(String theme) async {
    await _repository.setTheme(theme);
    _theme = theme;
    notifyListeners();
  }
}
