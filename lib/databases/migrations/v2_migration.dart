import 'package:sqflite/sqflite.dart';

/// V1.5 → V2.0 数据库迁移脚本
class V2Migration {
  /// 执行迁移
  static Future<void> migrate(Database db) async {
    await db.execute('ALTER TABLE books ADD COLUMN start_date TEXT');
    await db.execute(
        "ALTER TABLE books ADD COLUMN status TEXT DEFAULT 'finished'");
    await db.execute('ALTER TABLE books ADD COLUMN abandoned_at TEXT');
    await db.execute('ALTER TABLE books ADD COLUMN finished_at TEXT');

    // 已有数据：start_date = read_date，status = finished
    await db.execute(
        "UPDATE books SET start_date = read_date, status = 'finished' WHERE status IS NULL");

    // 新增索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_status ON books(status)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_start_date ON books(start_date)');
  }

  /// 回滚迁移（重建表）
  static Future<void> rollback(Database db) async {
    await db.execute('''
      CREATE TABLE books_v1 AS
      SELECT id, title, author, read_date, rating, notes, cover_path, created_at
      FROM books
    ''');
    await db.execute('DROP TABLE books');
    await db.execute('ALTER TABLE books_v1 RENAME TO books');
  }
}
