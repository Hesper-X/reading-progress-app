import 'package:sqflite/sqflite.dart';
import '../models/year_goal.dart';
import '../databases/database_helper.dart';

/// 年度目标数据仓库（V3.0 新增）
class GoalRepository {
  final DatabaseHelper _db;

  GoalRepository(this._db);

  /// 获取指定年份的目标
  Future<YearGoal?> getGoal(int year) async {
    final db = await _db.database;
    final maps = await db.query(
      'year_goals',
      where: 'year = ?',
      whereArgs: [year],
    );
    if (maps.isEmpty) return null;
    return YearGoal.fromMap(maps.first);
  }

  /// 获取或创建默认目标
  Future<YearGoal> getOrCreateGoal(int year, {int defaultTarget = 52}) async {
    final existing = await getGoal(year);
    if (existing != null) return existing;

    final db = await _db.database;
    await db.insert('year_goals', {
      'year': year,
      'target': defaultTarget,
      'is_set_by_user': 0,
    });
    return YearGoal(year: year, target: defaultTarget);
  }

  /// 设置年度目标
  Future<void> setGoal(int year, int target) async {
    final db = await _db.database;
    await db.insert(
      'year_goals',
      {
        'year': year,
        'target': target,
        'is_set_by_user': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取所有年份的目标列表（倒序）
  Future<List<YearGoal>> getAllGoals() async {
    final db = await _db.database;
    final maps = await db.query(
      'year_goals',
      orderBy: 'year DESC',
    );
    return maps.map((m) => YearGoal.fromMap(m)).toList();
  }

  /// 获取目标中的最大年份
  Future<int?> getMaxYear() async {
    final db = await _db.database;
    final result =
        await db.rawQuery('SELECT MAX(year) as max_year FROM year_goals');
    return result.first['max_year'] as int?;
  }

  /// 删除指定年份目标
  Future<void> deleteGoal(int year) async {
    final db = await _db.database;
    await db.delete('year_goals', where: 'year = ?', whereArgs: [year]);
  }
}
