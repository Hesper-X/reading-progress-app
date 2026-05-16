import 'package:sqflite/sqflite.dart';
import '../models/setting_key.dart';
import '../databases/database_helper.dart';

/// 设置数据仓库
class SettingsRepository {
  final DatabaseHelper _db;

  SettingsRepository(this._db);

  /// 获取设置值
  Future<String?> getValue(SettingKey key) async {
    final db = await _db.database;
    final result = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key.key],
    );
    return result.isNotEmpty ? result.first['value'] as String : key.defaultValue;
  }

  /// 设置值
  Future<void> setValue(SettingKey key, String value) async {
    final db = await _db.database;
    await db.insert(
      'settings',
      {'key': key.key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取年度目标
  Future<int> getYearlyGoal() async {
    final value = await getValue(SettingKey.yearlyGoal);
    return int.tryParse(value ?? '0') ?? 0;
  }

  /// 设置年度目标
  Future<void> setYearlyGoal(int goal) async {
    assert(goal >= 1 && goal <= 500);
    await setValue(SettingKey.yearlyGoal, goal.toString());
  }

  /// 获取主题
  Future<String> getTheme() async {
    return (await getValue(SettingKey.theme)) ?? 'light';
  }

  /// 设置主题
  Future<void> setTheme(String theme) async {
    assert(theme == 'light' || theme == 'dark');
    await setValue(SettingKey.theme, theme);
  }

  /// 获取每日提醒开关
  Future<bool> getDailyReminder() async {
    final value = await getValue(SettingKey.dailyReminder);
    return value == 'true';
  }

  /// 设置每日提醒开关
  Future<void> setDailyReminder(bool enabled) async {
    await setValue(SettingKey.dailyReminder, enabled ? 'true' : 'false');
  }

  /// 获取提醒时间
  Future<String> getReminderTime() async {
    return (await getValue(SettingKey.reminderTime)) ?? '21:00';
  }

  /// 设置提醒时间
  Future<void> setReminderTime(String time) async {
    await setValue(SettingKey.reminderTime, time);
  }

  /// 是否已购买 Pro
  Future<bool> isProPurchased() async {
    final value = await getValue(SettingKey.proPurchased);
    return value == 'true';
  }

  /// 设置 Pro 购买状态
  Future<void> setProPurchased(bool purchased) async {
    await setValue(SettingKey.proPurchased, purchased ? 'true' : 'false');
  }

  /// 获取所有设置
  Future<Map<String, String>> getAll() async {
    final db = await _db.database;
    final result = await db.query('settings');
    return {for (var row in result) row['key'] as String: row['value'] as String};
  }
}
