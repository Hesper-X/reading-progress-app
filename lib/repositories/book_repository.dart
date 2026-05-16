import '../models/book.dart';
import '../databases/database_helper.dart';

/// 书籍数据仓库（V3.0）
class BookRepository {
  final DatabaseHelper _db;

  BookRepository(this._db);

  // ============ 查询方法 ============

  /// 获取想读书籍（书架「想读」Tab）
  Future<List<Book>> getWishBooks() async {
    final db = await _db.database;
    final maps = await db.query(
      'books',
      where: 'status = ?',
      whereArgs: ['wish'],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  /// 获取在读书籍
  Future<List<Book>> getReadingBooks() async {
    final db = await _db.database;
    final maps = await db.query(
      'books',
      where: 'status = ?',
      whereArgs: ['reading'],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  /// 获取已读书籍（可指定年份范围）
  Future<List<Book>> getDoneBooks({int? year, int? month}) async {
    final db = await _db.database;
    String where = "status = 'done'";
    List<dynamic> whereArgs = [];

    if (year != null && month != null) {
      where += " AND strftime('%Y', read_date) = ? AND strftime('%m', read_date) = ?";
      whereArgs = [year.toString(), month.toString().padLeft(2, '0')];
    } else if (year != null) {
      where += " AND strftime('%Y', read_date) = ?";
      whereArgs = [year.toString()];
    }

    final maps = await db.query(
      'books',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'read_date DESC',
    );
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  /// 获取所有书籍（不含已放弃）
  Future<List<Book>> getAll() async {
    final db = await _db.database;
    final maps = await db.query(
      'books',
      where: "status != 'abandoned'",
      orderBy: "CASE WHEN status = 'reading' THEN 0 WHEN status = 'wish' THEN 1 ELSE 2 END, created_at DESC",
    );
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  /// 根据 ID 获取单本书籍
  Future<Book?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query('books', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Book.fromMap(maps.first);
  }

  /// 获取首页在读书籍（最多 2 本）
  Future<List<Book>> getReadingBooksForHome() async {
    final db = await _db.database;
    final maps = await db.query(
      'books',
      where: 'status = ?',
      whereArgs: ['reading'],
      orderBy: 'start_date ASC',
      limit: 2,
    );
    return maps.map((m) => Book.fromMap(m)).toList();
  }

  // ============ 写操作 ============

  /// 添加书籍
  Future<int> insert(Book book) async {
    final db = await _db.database;
    return await db.insert('books', book.toMap());
  }

  /// 标记读完（V3.0: read_count +1）
  Future<int> markAsDone({
    required int id,
    required DateTime readDate,
    required double rating,
    String? notes,
  }) async {
    final db = await _db.database;
    return await db.update(
      'books',
      {
        'read_date':
            '${readDate.year}-${readDate.month.toString().padLeft(2, '0')}-${readDate.day.toString().padLeft(2, '0')}',
        'rating': (rating * 10).round(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'status': 'done',
        'read_count': 1, // 首次读完
        'finished_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 重复读完（已有 done 记录再次读完，read_count +1）
  Future<int> markReadAgain({
    required int id,
    required DateTime readDate,
    required double rating,
    String? notes,
  }) async {
    final db = await _db.database;
    return await db.update(
      'books',
      {
        'read_date':
            '${readDate.year}-${readDate.month.toString().padLeft(2, '0')}-${readDate.day.toString().padLeft(2, '0')}',
        'rating': (rating * 10).round(),
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        'read_count': 1,
        'finished_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 放弃阅读
  Future<int> abandon(int id) async {
    final db = await _db.database;
    return await db.update(
      'books',
      {
        'status': 'abandoned',
        'abandoned_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 更新书籍
  Future<int> update(Book book) async {
    final db = await _db.database;
    return await db.update(
      'books',
      book.toMap(),
      where: 'id = ?',
      whereArgs: [book.id],
    );
  }

  /// 删除书籍
  Future<int> delete(int id) async {
    final db = await _db.database;
    return await db.delete('books', where: 'id = ?', whereArgs: [id]);
  }

  // ============ V3.0 统计查询 ============

  /// 最爱书籍 Top3
  Future<List<Map<String, dynamic>>> getFavoriteBooks(int? year, int? month) async {
    final db = await _db.database;
    List<String> conditions = ["status = 'done'"];
    List<dynamic> args = [];

    if (year != null && month != null) {
      conditions.add("strftime('%Y', read_date) = ? AND strftime('%m', read_date) = ?");
      args.addAll([year.toString(), month.toString().padLeft(2, '0')]);
    } else if (year != null) {
      conditions.add("strftime('%Y', read_date) = ?");
      args.add(year.toString());
    }

    final where = conditions.join(' AND ');
    return await db.rawQuery('''
      SELECT title, author, rating, read_date, read_count
      FROM books
      WHERE $where AND read_date IS NOT NULL
      ORDER BY read_count DESC, rating DESC, read_date DESC
      LIMIT 3
    ''', args);
  }

  /// 最长与最短阅读
  Future<Map<String, dynamic>?> getLongestBook(int? year, int? month) async {
    final db = await _db.database;
    List<String> conditions = ["status = 'done' AND julianday(read_date) - julianday(start_date) > 0"];
    List<dynamic> args = [];

    if (year != null && month != null) {
      conditions.add("strftime('%Y', read_date) = ? AND strftime('%m', read_date) = ?");
      args.addAll([year.toString(), month.toString().padLeft(2, '0')]);
    } else if (year != null) {
      conditions.add("strftime('%Y', read_date) = ?");
      args.add(year.toString());
    }

    final result = await db.rawQuery('''
      SELECT title, author,
             CAST(julianday(read_date) - julianday(start_date) AS INTEGER) as days
      FROM books
      WHERE ${conditions.join(' AND ')}
      ORDER BY days DESC
      LIMIT 1
    ''', args);
    return result.isNotEmpty ? result.first : null;
  }

  Future<Map<String, dynamic>?> getShortestBook(int? year, int? month) async {
    final db = await _db.database;
    List<String> conditions = ["status = 'done' AND julianday(read_date) - julianday(start_date) > 0"];
    List<dynamic> args = [];

    if (year != null && month != null) {
      conditions.add("strftime('%Y', read_date) = ? AND strftime('%m', read_date) = ?");
      args.addAll([year.toString(), month.toString().padLeft(2, '0')]);
    } else if (year != null) {
      conditions.add("strftime('%Y', read_date) = ?");
      args.add(year.toString());
    }

    final result = await db.rawQuery('''
      SELECT title, author,
             CAST(julianday(read_date) - julianday(start_date) AS INTEGER) as days
      FROM books
      WHERE ${conditions.join(' AND ')}
      ORDER BY days ASC
      LIMIT 1
    ''', args);
    return result.isNotEmpty ? result.first : null;
  }

  /// 已读书单
  Future<List<Book>> getReadList(int? year, int? month) async {
    return getDoneBooks(year: year, month: month);
  }

  /// 最爱作者 Top3
  Future<List<Map<String, dynamic>>> getFavoriteAuthors(int? year, int? month) async {
    final db = await _db.database;
    List<String> conditions = ["status = 'done'", "author IS NOT NULL", "author != ''"];
    List<dynamic> args = [];

    if (year != null && month != null) {
      conditions.add("strftime('%Y', read_date) = ? AND strftime('%m', read_date) = ?");
      args.addAll([year.toString(), month.toString().padLeft(2, '0')]);
    } else if (year != null) {
      conditions.add("strftime('%Y', read_date) = ?");
      args.add(year.toString());
    }

    final where = conditions.join(' AND ');
    return await db.rawQuery('''
      SELECT author, COUNT(*) as book_count, MAX(rating) as max_rating, MAX(read_date) as latest_read
      FROM books
      WHERE $where
      GROUP BY author
      ORDER BY book_count DESC, max_rating DESC, latest_read DESC
      LIMIT 3
    ''', args);
  }

  /// 月度趋势（柱状图数据）
  Future<Map<int, int>> getMonthlyTrend(int year) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT strftime('%m', read_date) as month, COUNT(*) as count
      FROM books
      WHERE status = 'done' AND strftime('%Y', read_date) = ?
      GROUP BY month
      ORDER BY month
    ''', [year.toString()]);

    final trend = <int, int>{};
    for (int i = 1; i <= 12; i++) { trend[i] = 0; }
    for (final row in result) {
      final m = int.tryParse(row['month'] as String? ?? '') ?? 0;
      trend[m] = (row['count'] as int?) ?? 0;
    }
    return trend;
  }

  /// 年度对比（Pro全生涯）
  Future<List<Map<String, dynamic>>> getYearlyComparison() async {
    final db = await _db.database;
    return await db.rawQuery('''
      SELECT strftime('%Y', read_date) as year, COUNT(*) as count
      FROM books
      WHERE status = 'done'
      GROUP BY year
      ORDER BY year
    ''');
  }

  /// 获取可筛选的年份列表（已读数据的年份 + 当年）
  Future<List<int>> getAvailableYears() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT DISTINCT CAST(strftime('%Y', read_date) AS INTEGER) as year
      FROM books
      WHERE status = 'done' AND read_date IS NOT NULL
      ORDER BY year DESC
    ''');
    final years = result.map((r) => r['year'] as int).toSet();
    years.add(DateTime.now().year);
    final sorted = years.toList()..sort((a, b) => b.compareTo(a));
    return sorted;
  }

  // ============ 统计查询（V2.0 兼容） ============

  /// 当年已读完成数量
  Future<int> countCurrentYearDone() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM books
      WHERE status = 'done'
        AND strftime('%Y', read_date) = strftime('%Y', 'now')
    ''');
    return (result.first['count'] as int?) ?? 0;
  }

  /// 当月已读数
  Future<int> countCurrentMonthDone() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM books
      WHERE status = 'done'
        AND strftime('%Y', read_date) = strftime('%Y', 'now')
        AND strftime('%m', read_date) = strftime('%m', 'now')
    ''');
    return (result.first['count'] as int?) ?? 0;
  }

  /// 当月在读数量
  Future<int> countCurrentMonthReading() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM books WHERE status = 'reading'");
    return (result.first['count'] as int?) ?? 0;
  }

  /// 总活跃书籍数（不含已放弃，免费版限制用）
  Future<int> getTotalActiveCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM books WHERE status IN ('wish', 'reading', 'done')");
    return (result.first['count'] as int?) ?? 0;
  }

  /// 阅读周期统计
  Future<Map<String, dynamic>> getYearlyCycleStats(int year) async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_books,
        ROUND(AVG(julianday(read_date) - julianday(start_date)), 1) as avg_cycle,
        MIN(julianday(read_date) - julianday(start_date)) as fastest,
        MAX(julianday(read_date) - julianday(start_date)) as slowest,
        ROUND(AVG(rating), 1) as avg_rating
      FROM books
      WHERE status = 'done'
        AND strftime('%Y', read_date) = ?
    ''', [year.toString()]);
    return result.first;
  }

  /// 当年平均评分
  Future<double?> getCurrentYearAvgRating() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT ROUND(AVG(rating), 1) as avg
      FROM books
      WHERE status = 'done'
        AND strftime('%Y', read_date) = strftime('%Y', 'now')
        AND rating IS NOT NULL
    ''');
    return result.first['avg'] as double?;
  }

  // ============ 生涯查询 ============

  /// 累计读书总数
  Future<int> getTotalDoneCount() async {
    final db = await _db.database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as count FROM books WHERE status = 'done'");
    return (result.first['count'] as int?) ?? 0;
  }

  /// 所有书籍平均评分
  Future<double?> getOverallAvgRating() async {
    final db = await _db.database;
    final result = await db.rawQuery('''
      SELECT ROUND(AVG(rating), 1) as avg
      FROM books WHERE status = 'done' AND rating IS NOT NULL
    ''');
    return result.first['avg'] as double?;
  }
}
