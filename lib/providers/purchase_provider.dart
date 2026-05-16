import 'package:flutter/foundation.dart';
import '../repositories/settings_repository.dart';

/// 内购状态管理
class PurchaseProvider with ChangeNotifier {
  final SettingsRepository _repository;

  bool _isPro = false;
  bool _isLoading = false;
  String? _error;

  PurchaseProvider({required SettingsRepository repository})
      : _repository = repository;

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 加载购买状态
  Future<void> loadPurchaseStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isPro = await _repository.isProPurchased();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 设置 Pro 状态
  Future<void> setPro(bool purchased) async {
    await _repository.setProPurchased(purchased);
    _isPro = purchased;
    notifyListeners();
  }

  /// 清除错误
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
