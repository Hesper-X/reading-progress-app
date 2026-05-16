import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// 数据库助手（单例）— V3.0
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static const String _dbName = 'reading_progress.db';
  static const int _dbVersion = 3; // V3.0: version 3

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // V3.0: books 表（三状态 wish/reading/done + read_count）
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL DEFAULT '',
        cover_path TEXT,
        rating INTEGER,
        notes TEXT,
        read_date DATE,
        start_date TEXT NOT NULL,
        status TEXT DEFAULT 'wish' CHECK(status IN ('wish', 'reading', 'done', 'abandoned')),
        abandoned_at DATETIME,
        finished_at DATETIME,
        read_count INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // V3.0: year_goals 表（年度目标独立存储）
    await db.execute('''
      CREATE TABLE year_goals (
        year INTEGER PRIMARY KEY,
        target INTEGER NOT NULL DEFAULT 52,
        is_set_by_user INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // settings 表
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // 索引
    await db.execute('CREATE INDEX idx_status ON books(status)');
    await db.execute('CREATE INDEX idx_read_date ON books(read_date)');
    await db.execute('CREATE INDEX idx_start_date ON books(start_date)');
    await db.execute('CREATE INDEX idx_finish_date ON books(finished_at)');
    await db.execute('CREATE INDEX idx_author ON books(author)');

    // 默认设置
    await db.execute("INSERT OR IGNORE INTO settings VALUES ('yearly_goal', '52')");
    await db.execute("INSERT OR IGNORE INTO settings VALUES ('theme', 'light')");
    await db.execute("INSERT OR IGNORE INTO settings VALUES ('daily_reminder', 'false')");
    await db.execute("INSERT OR IGNORE INTO settings VALUES ('reminder_time', '21:00')");
    await db.execute("INSERT OR IGNORE INTO settings VALUES ('pro_purchased', 'false')");
    await db.execute("INSERT OR IGNORE INTO settings VALUES ('backup_enabled', 'false')");

    // 初始化当年年度目标
    final year = DateTime.now().year;
    await db.execute(
        "INSERT OR IGNORE INTO year_goals (year, target, is_set_by_user) VALUES ($year, 52, 0)");
  }

  /// 数据库迁移
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // V1.5 → V2.0
      await db.execute('ALTER TABLE books ADD COLUMN start_date TEXT');
      await db.execute("ALTER TABLE books ADD COLUMN status TEXT DEFAULT 'reading'");
      await db.execute('ALTER TABLE books ADD COLUMN abandoned_at TEXT');
      await db.execute('ALTER TABLE books ADD COLUMN finished_at TEXT');
      await db.execute(
          "UPDATE books SET start_date = read_date, status = 'reading' WHERE status IS NULL");
      await db.execute('CREATE INDEX IF NOT EXISTS idx_status ON books(status)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_start_date ON books(start_date)');
    }

    if (oldVersion < 3) {
      // V2.0 → V3.0
      await _upgradeV2ToV3(db);
    }
  }

  /// V2.0 → V3.0 迁移
  Future<void> _upgradeV2ToV3(Database db) async {
    // Step 1: 备份旧表
    await db.execute('ALTER TABLE books RENAME TO books_v2');

    // Step 2: 创建新表（三状态 wish/reading/done + read_count）
    await db.execute('''
      CREATE TABLE books (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        author TEXT NOT NULL DEFAULT '',
        cover_path TEXT,
        rating INTEGER,
        notes TEXT,
        read_date DATE,
        start_date TEXT NOT NULL,
        status TEXT DEFAULT 'wish' CHECK(status IN ('wish', 'reading', 'done', 'abandoned')),
        abandoned_at DATETIME,
        finished_at DATETIME,
        read_count INTEGER NOT NULL DEFAULT 1,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Step 3: 迁移数据
    // finished → done, 已有 status 保持不变
    // author: 处理 null → ''
    // read_count: 默认 1
    await db.execute('''
      INSERT INTO books (id, title, author, cover_path, rating, notes, read_date, start_date, status, abandoned_at, finished_at, read_count, created_at)
      SELECT
        id,
        title,
        COALESCE(author, '') as author,
        cover_path,
        rating,
        notes,
        read_date,
        start_date,
        CASE WHEN status = 'finished' THEN 'done' ELSE COALESCE(status, 'reading') END as status,
        abandoned_at,
        finished_at,
        1 as read_count,
        COALESCE(created_at, datetime('now')) as created_at
      FROM books_v2
    ''');

    // Step 4: 删除旧表
    await db.execute('DROP TABLE books_v2');

    // Step 5: 重建索引
    await db.execute('CREATE INDEX IF NOT EXISTS idx_status ON books(status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_read_date ON books(read_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_start_date ON books(start_date)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_finish_date ON books(finished_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_author ON books(author)');

    // Step 6: 创建 year_goals 表
    await db.execute('''
      CREATE TABLE IF NOT EXISTS year_goals (
        year INTEGER PRIMARY KEY,
        target INTEGER NOT NULL DEFAULT 52,
        is_set_by_user INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Step 7: 迁移当年目标
    final year = DateTime.now().year;
    await db.execute('''
      INSERT OR IGNORE INTO year_goals (year, target, is_set_by_user)
      VALUES ($year, 
        COALESCE((SELECT CAST(value AS INTEGER) FROM settings WHERE key = 'yearly_goal'), 52),
        0)
    ''');

    // Step 8: 更新默认目标为52（V3.0 新默认值）
    await db.execute("UPDATE settings SET value = '52' WHERE key = 'yearly_goal' AND value = '50'");
  }

  /// 关闭数据库
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
