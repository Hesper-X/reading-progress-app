import '../models/checkin.dart';
import '../databases/database_helper.dart';

/// 打卡数据仓库（V3.5）
class CheckinRepository {
  final DatabaseHelper _db;

  CheckinRepository(this._db);

  // ============ 写操作 ============

  /// 添加一条打卡记录
  /// 返回新记录的 id
  Future<int> addCheckin(CheckinDetail detail) async {
    final db = await _db.database;
    return await db.insert('checkin_details', detail.toMap());
  }

  /// 删除某本书的所有打卡记录
  /// books 表不受影响
  Future<int> deleteBookCheckins(int bookId) async {
    final db = await _db.database;
    return await db.delete(
      'checkin_details',
      where: 'book_id = ?',
      whereArgs: [bookId],
    );
  }

  /// 删除单条打卡记录
  Future<int> deleteCheckin(int checkinId) async {
    final db = await _db.database;
    return await db.delete(
      'checkin_details',
      where: 'id = ?',
      whereArgs: [checkinId],
    );
  }

  // ============ 查询：单日 ============

  /// 获取某日的所有打卡记录（含书籍标题）
  Future<CheckinDaySummary> getDaySummary(String date) async {
    final db = await _db.database;
    final details = await db.rawQuery('''
      SELECT cd.* FROM checkin_details cd
      WHERE cd.checkin_date = ?
      ORDER BY cd.created_at ASC
    ''', [date]);

    final detailList = details.map((m) => CheckinDetail.fromMap(m)).toList();

    // 获取书籍名称
    final bookIds = detailList.map((d) => d.bookId).toSet().toList();
    final bookTitles = <int, String>{};
    for (final id in bookIds) {
      final result = await db.rawQuery(
        'SELECT id, title FROM books WHERE id = ?',
        [id],
      );
      if (result.isNotEmpty) {
        bookTitles[id] = result.first['title'] as String;
      }
    }

    // 计算连续天数
    final streakDays = await _calculateStreakTo(date);

    return CheckinDaySummary(
      details: detailList,
      bookTitles: bookTitles,
      streakDays: streakDays,
    );
  }

  // ============ 查询：日历 ============

  /// 获取某个月份所有有打卡记录的日期集合
  /// 返回 Set<String>，如 {'2026-06-01', '2026-06-03', ...}
  Future<Set<String>> getMonthCheckinDates(int year, int month) async {
    final db = await _db.database;
    final monthStr = month.toString().padLeft(2, '0');
    final result = await db.rawQuery('''
      SELECT DISTINCT checkin_date
      FROM checkin_details
      WHERE checkin_date LIKE '$year-$monthStr-%'
    ''');

    return result.map((r) => r['checkin_date'] as String).toSet();
  }

  /// 获取今天是否有打卡记录
  Future<bool> hasTodayCheckin() async {
    final today = _formatDate(DateTime.now());
    final db = await _db.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM checkin_details WHERE checkin_date = ?',
      [today],
    );
    return (result.first['cnt'] as int) > 0;
  }

  // ============ 查询：统计/联动 ============

  /// 获取某本书的阅读累计统计
  /// 返回 (totalMinutes: int, checkinDays: int)
  Future<Map<String, int>> getBookCheckinStats(int bookId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(duration_min), 0) as total_minutes,
        COUNT(DISTINCT checkin_date) as checkin_days
      FROM checkin_details
      WHERE book_id = ?
    ''', [bookId]);
    return {
      'totalMinutes': (result.first['total_minutes'] as num?)?.toInt() ?? 0,
      'checkinDays': (result.first['checkin_days'] as num?)?.toInt() ?? 0,
    };
  }

  /// 获取多本书的打卡统计（批量查询，用于书架页）
  /// 返回 Map<bookId, {totalMinutes, checkinDays}>
  Future<Map<int, Map<String, int>>> getBooksCheckinStats(
      List<int> bookIds) async {
    if (bookIds.isEmpty) return {};
    final db = await _db.database;
    final placeholders = bookIds.map((_) => '?').join(',');
    final result = await db.rawQuery('''
      SELECT
        book_id,
        COALESCE(SUM(duration_min), 0) as total_minutes,
        COUNT(DISTINCT checkin_date) as checkin_days
      FROM checkin_details
      WHERE book_id IN ($placeholders)
      GROUP BY book_id
    ''', bookIds);

    final statsMap = <int, Map<String, int>>{};
    for (final row in result) {
      final bookId = row['book_id'] as int;
      statsMap[bookId] = {
        'totalMinutes': (row['total_minutes'] as num?)?.toInt() ?? 0,
        'checkinDays': (row['checkin_days'] as num?)?.toInt() ?? 0,
      };
    }
    return statsMap;
  }

  /// 阅读投入 Top3（统计页）
  /// 返回: [{bookId, totalMinutes, checkinDays, title, author}, ...]
  Future<List<Map<String, dynamic>>> getTop3CheckinBooks(
      {int? year, int? month}) async {
    final db = await _db.database;
    List<String> conditions = [];
    List<dynamic> args = [];

    if (year != null && month != null) {
      conditions.add(
          "cd.checkin_date LIKE '${year}-${month.toString().padLeft(2, '0')}-%'");
    } else if (year != null) {
      conditions.add("cd.checkin_date LIKE '$year-%'");
    }

    final whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final result = await db.rawQuery('''
      SELECT
        cd.book_id,
        COALESCE(SUM(cd.duration_min), 0) as total_minutes,
        COUNT(DISTINCT cd.checkin_date) as checkin_days,
        b.title,
        b.author
      FROM checkin_details cd
      JOIN books b ON b.id = cd.book_id
      $whereClause
      GROUP BY cd.book_id
      ORDER BY total_minutes DESC
      LIMIT 3
    ''', args);

    return result;
  }

  /// 获取某周期总阅读时长和打卡天数（合计行用）
  Future<Map<String, int>> getTotalCheckinStats({int? year, int? month}) async {
    final db = await _db.database;
    List<String> conditions = [];
    List<dynamic> args = [];

    if (year != null && month != null) {
      conditions.add(
          "checkin_date LIKE '${year}-${month.toString().padLeft(2, '0')}-%'");
    } else if (year != null) {
      conditions.add("checkin_date LIKE '$year-%'");
    }

    final whereClause =
        conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(duration_min), 0) as total_minutes,
        COUNT(DISTINCT checkin_date) as total_days
      FROM checkin_details
      $whereClause
    ''', args);

    return {
      'totalMinutes': (result.first['total_minutes'] as num?)?.toInt() ?? 0,
      'totalDays': (result.first['total_days'] as num?)?.toInt() ?? 0,
    };
  }

  // ============ 查询：笔记时间轴 ============

  /// 获取某本书的所有打卡记录（按日期倒序）
  Future<List<CheckinDetail>> getBookCheckins(int bookId) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT * FROM checkin_details
      WHERE book_id = ?
      ORDER BY checkin_date DESC, created_at ASC
    ''', [bookId]);
    return result.map((m) => CheckinDetail.fromMap(m)).toList();
  }

  // ============ 全量导出 ============

  /// 获取所有打卡记录（按日期和创建时间排序，用于导出）
  Future<List<CheckinDetail>> getAllCheckins() async {
    final db = await _db.database;
    final result = await db.query(
      'checkin_details',
      orderBy: 'checkin_date ASC, created_at ASC',
    );
    return result.map((m) => CheckinDetail.fromMap(m)).toList();
  }

  // ============ 连续天数计算 ============

  /// 计算截至某天的连续打卡天数
  Future<int> _calculateStreakTo(String dateStr) async {
    final db = await _db.database;
    final date = DateTime.tryParse(dateStr);
    if (date == null) return 0;

    int streak = 0;
    var current = DateTime(date.year, date.month, date.day);

    // 从当天开始向前连续追溯
    while (true) {
      final dateKey = _formatDate(current);
      final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM checkin_details WHERE checkin_date = ?',
        [dateKey],
      );
      if ((result.first['cnt'] as int) > 0) {
        streak++;
        current = current.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  /// 计算今天的连续打卡天数
  Future<int> getCurrentStreak() async {
    return await _calculateStreakTo(_formatDate(DateTime.now()));
  }

  // ============ 工具 ============

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
