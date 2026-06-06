import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/book.dart';
import '../repositories/book_repository.dart';
import '../repositories/settings_repository.dart';

/// 书籍状态管理（V3.0：三状态 wish/reading/done）
/// 包含年度目标达成庆祝状态
class BooksProvider with ChangeNotifier {
  final BookRepository _repository;
  final SettingsRepository _settingsRepository;

  List<Book> _books = [];
  List<Book> _wishBooks = [];
  List<Book> _readingBooks = [];
  List<Book> _doneBooks = [];
  bool _isLoading = false;
  String? _error;

  // ============ 庆祝动画状态 ============
  bool _celebrationAchieved = false;
  bool _celebrationTriggered = false;
  bool _shareButtonClicked = false;
  String _celebrationDate = '';
  int _targetVersion = 0;

  BooksProvider({
    required BookRepository repository,
    required SettingsRepository settingsRepository,
  })  : _repository = repository,
        _settingsRepository = settingsRepository;

  // ============ Getters ============

  List<Book> get books => _books;
  List<Book> get wishBooks => _wishBooks;
  List<Book> get readingBooks => _readingBooks;
  List<Book> get doneBooks => _doneBooks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// V2.0 兼容：finishedBooks 映射到 doneBooks
  List<Book> get finishedBooks => _doneBooks;

  bool get celebrationAchieved => _celebrationAchieved;
  bool get celebrationTriggered => _celebrationTriggered;
  bool get shareButtonClicked => _shareButtonClicked;
  String get celebrationDate => _celebrationDate;
  int get targetVersion => _targetVersion;

  /// 当年已读完成数量
  int get currentYearCount =>
      _doneBooks.where((b) => b.readDate?.year == DateTime.now().year).length;

  /// 当前年度进度（0.0 ~ 1.0），需要外部传 yearlyGoal
  double progressWithGoal(int yearlyGoal) =>
      yearlyGoal > 0 ? (currentYearCount / yearlyGoal).clamp(0.0, 1.0) : 0.0;

  /// 当前在读数量
  int get readingCount => _readingBooks.length;

  /// 想读数量
  int get wishCount => _wishBooks.length;

  /// 已读数量
  int get doneCount => _doneBooks.length;

  /// 总活跃书籍数（不含已放弃）
  int get activeCount => _wishBooks.length + _readingBooks.length + _doneBooks.length;

  // ============ 数据加载 ============

  Future<void> loadBooks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _books = await _repository.getAll();
      _wishBooks = await _repository.getWishBooks();
      _readingBooks = await _repository.getReadingBooks();
      _doneBooks = await _repository.getDoneBooks();

      _refreshCelebrationStatus();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _refreshCelebrationStatus() async {
    // 从数据库读取年度目标（不依赖 SettingsProvider）
    try {
      final goal = await _settingsRepository.getYearlyGoal();
      final isGoalMet = currentYearCount >= goal && goal > 0;
      if (isGoalMet != _celebrationAchieved) {
        if (isGoalMet) {
          _celebrationAchieved = true;
          _celebrationTriggered = false;
          _shareButtonClicked = false;
          _celebrationDate = _todayStr();
        }
      }
    } catch (_) {}
  }

  /// 外部触发庆祝（根据 SettingsProvider.yearlyGoal）
  void triggerCelebrationIfNeeded(int yearlyGoal) {
    final isGoalMet = currentYearCount >= yearlyGoal && yearlyGoal > 0;
    if (isGoalMet != _celebrationAchieved) {
      if (isGoalMet) {
        _celebrationAchieved = true;
        _celebrationTriggered = false;
        _shareButtonClicked = false;
        _celebrationDate = _todayStr();
      }
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  // ============ 庆祝操作 ============

  void markCelebrationTriggered() {
    _celebrationTriggered = true;
    notifyListeners();
  }

  void markShareClicked() {
    _shareButtonClicked = true;
    notifyListeners();
  }

  void resetCelebrationStatus() {
    _celebrationAchieved = false;
    _celebrationTriggered = false;
    _shareButtonClicked = false;
    _celebrationDate = '';
    _targetVersion++;
    notifyListeners();
  }

  bool shouldShowShareEntry() {
    final today = _todayStr();
    return _celebrationAchieved &&
        _celebrationTriggered &&
        !_shareButtonClicked &&
        _celebrationDate == today;
  }

  // ============ 操作 ============

  /// 添加书籍（V3.0：双模式 wish/reading）
  Future<bool> addBook({
    required String title,
    String? author,
    String? coverPath,
    DateTime? startDate,
    BookStatus status = BookStatus.reading,
  }) async {
    try {
      // 将封面图片复制到应用私有目录，避免临时路径失效
      String? savedCoverPath;
      if (coverPath != null && coverPath.isNotEmpty) {
        final dir = await getApplicationDocumentsDirectory();
        final coversDir = Directory('${dir.path}/covers');
        if (!await coversDir.exists()) {
          await coversDir.create(recursive: true);
        }
        final ext = coverPath.contains('.') ? '.${coverPath.split('.').last}' : '.jpg';
        final destPath = '${coversDir.path}/${DateTime.now().millisecondsSinceEpoch}$ext';
        await File(coverPath).copy(destPath);
        savedCoverPath = destPath;
      }

      final book = Book(
        title: title,
        author: author ?? '',
        coverPath: savedCoverPath,
        startDate: startDate ?? DateTime.now(),
        status: status,
      );
      await _repository.insert(book);
      await loadBooks();
      return true;
    } catch (e) {
      _error = '添加失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// V3.3 已读新增模式：直接将一书标记为已读（非从在读流转）
  Future<void> addDoneBook(Book book) async {
    await _repository.insert(book);
    await loadBooks();
  }

  /// 标记读完（V3.0：rating 改用 double）
  Future<bool> markAsDone({
    required int bookId,
    required DateTime readDate,
    required double rating,
    String? notes,
  }) async {
    try {
      await _repository.markAsDone(
        id: bookId,
        readDate: readDate,
        rating: rating,
        notes: notes,
      );
      await loadBooks();
      return true;
    } catch (e) {
      _error = '标记失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 放弃阅读
  Future<bool> abandonBook(int bookId) async {
    try {
      await _repository.abandon(bookId);
      await loadBooks();
      return true;
    } catch (e) {
      _error = '操作失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 删除书籍
  Future<bool> deleteBook(int bookId) async {
    try {
      await _repository.delete(bookId);
      await loadBooks();
      return true;
    } catch (e) {
      _error = '删除失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// V3.2 编辑书籍（保留id UPDATE）
  Future<bool> updateBook({
    required int bookId,
    required String title,
    String? author,
    String? coverPath,
    DateTime? startDate,
    DateTime? readDate,
    double? rating,
    String? notes,
    BookStatus? status,
  }) async {
    try {
      // 找到原有记录
      final existing = _books.firstWhere((b) => b.id == bookId);

      final updated = Book(
        id: existing.id,
        title: title,
        author: author ?? existing.author,
        coverPath: coverPath ?? existing.coverPath,
        startDate: startDate ?? existing.startDate,
        status: status ?? existing.status,
        rating: rating ?? existing.rating,
        notes: notes ?? existing.notes,
        readDate: readDate ?? existing.readDate,
        readCount: existing.readCount,
        abandonedAt: existing.abandonedAt,
        finishedAt: existing.finishedAt,
        createdAt: existing.createdAt,
      );

      await _repository.update(updated);
      await loadBooks();
      return true;
    } catch (e) {
      _error = '编辑失败: $e';
      notifyListeners();
      return false;
    }
  }

  /// 更新年度目标（已废弃，由 SettingsProvider 统一管理）
  Future<void> updateYearlyGoal(int goal) async {
    resetCelebrationStatus();
    notifyListeners();
  }

  /// 免费版最大书籍数
  static const int freeMaxBooks = 5;

  /// 检查是否可添加新书（V3.4：免费版限制5本）
  Future<bool> canAddBook({bool isPro = false}) async {
    if (isPro) return true;
    final count = await _repository.getTotalActiveCount();
    return count < freeMaxBooks;
  }

  Future<int> getReadingBookCount() async {
    return (await _repository.getReadingBooks()).length;
  }

  /// V3.1 新增：年度趋势柱状图数据 — 按年份聚合已读完书籍
  /// 返回 Map<年份, 本数>，不限当年
  Map<int, int> getYearlyTrend() {
    final Map<int, int> trend = {};
    for (final book in _doneBooks) {
      if (book.readDate == null) continue;
      final year = book.readDate!.year;
      trend[year] = (trend[year] ?? 0) + 1;
    }
    return trend;
  }
}
