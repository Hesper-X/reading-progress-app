import 'package:flutter/material.dart';

/// 应用色彩规范
class AppColors {
  AppColors._();

  // ============ 浅色主题（主界面） ============

  /// 珊瑚红 - 主色
  static const Color primary = Color(0xFFFF6B6B);

  /// 浅红 - 背景装饰、Filter 选中背景
  static const Color primaryLight = Color(0xFFFFE3E3);

  /// 首页在读卡片渐变起始色
  static const Color primaryBg = Color(0xFFFFF5F5);

  /// 绿色 - 完成、成功反馈
  static const Color success = Color(0xFF51CF66);

  /// 深灰 - 主文字
  static const Color textPrimary = Color(0xFF212529);

  /// 中灰 - 次要文字
  static const Color textSecondary = Color(0xFF868E96);

  /// 辅助文字、placeholder
  static const Color textMuted = Color(0xFFADB5BD);

  /// 边框、分割线
  static const Color border = Color(0xFFDEE2E6);

  /// 卡片内分割线
  static const Color borderLight = Color(0xFFF1F3F5);

  /// 白色背景
  static const Color background = Color(0xFFFFFFFF);

  /// 页面背景色
  static const Color pageBg = Color(0xFFF5F5F5);

  /// 进度条未完成灰色
  static const Color progressRemaining = Color(0xFFE9ECEF);

  /// 星星评分激活色
  static const Color starActive = Color(0xFFFFD43B);

  /// 有感想卡片背景色
  static const Color notesBg = Color(0xFFFFFBF0);

  /// 有感想卡片边框色（金色）
  static const Color notesBorder = Color(0xFFFFE066);

  /// Tab 栏未选中
  static const Color tabInactive = Color(0xFF868E96);

  // ============ 深色主题（年度总结 / 阅读生涯） ============

  /// 深色页面背景渐变起始
  static const Color darkBg = Color(0xFF1A1A2E);

  /// 深色页面背景渐变中间
  static const Color darkBgMid = Color(0xFF16213E);

  /// 深色页面背景渐变结束
  static const Color darkBgEnd = Color(0xFF0F3460);

  /// 金色强调色（统计数值）
  static const Color gold = Color(0xFFFFD700);

  /// 金色次强调色
  static const Color goldLight = Color(0xFFFFC700);

  // ============ 启动页图标 ============

  static const Color launchBg = Color(0x4DFFEBEB);
  static const Color launchBorder = Color(0x59FFFFFF);

  // ============ Pro 升级页 ============

  static const Color priceButton = Color(0xFF1A1A2E);
}
