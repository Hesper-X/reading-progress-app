/// 书籍阅读状态枚举（V3.0）
enum BookStatus {
  /// 想读（🆕 V3.0）
  wish('wish'),

  /// 在读
  reading('reading'),

  /// 已读完（V2.0 finished 更名为 done）
  done('done'),

  /// 已放弃（不计入统计）
  abandoned('abandoned');

  final String value;
  const BookStatus(this.value);

  static BookStatus fromString(String value) {
    return BookStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => BookStatus.wish,
    );
  }
}

/// 书籍数据模型（V3.0）
class Book {
  final int? id;
  final String title;
  final String author; // V3.0: 非空
  final String? coverPath;
  final double? rating; // V3.0: double 类型，0.5 步长
  final String? notes; // V3.0: max 500 字符（不强制）
  final DateTime? readDate;
  final DateTime startDate;
  final BookStatus status; // V3.0: wish / reading / done
  final DateTime? abandonedAt;
  final DateTime? finishedAt;
  final int readCount; // 🆕 V3.0: 已读次数
  final DateTime? createdAt;

  const Book({
    this.id,
    required this.title,
    this.author = '',
    this.coverPath,
    this.rating,
    this.notes,
    this.readDate,
    required this.startDate,
    this.status = BookStatus.wish,
    this.abandonedAt,
    this.finishedAt,
    this.readCount = 1,
    this.createdAt,
  });

  // ============ 派生数据 ============

  /// 已读天数（在读状态时使用）
  int get elapsedDays => DateTime.now().difference(startDate).inDays;

  /// 阅读周期（已读状态时使用）
  int? get readingCycleDays =>
      readDate != null ? readDate!.difference(startDate).inDays : null;

  /// 格式化开始日期：2026年5月8日
  String get formattedStartDate =>
      '${startDate.year}年${startDate.month}月${startDate.day}日';

  /// 格式化读完日期：2026年5月8日
  String? get formattedReadDate => readDate != null
      ? '${readDate!.year}年${readDate!.month}月${readDate!.day}日'
      : null;

  // ============ 序列化 ============

  /// 从数据库 Map 创建（V3.0: rating 从 int(0-50) 转为 double(0.0-5.0)）
  factory Book.fromMap(Map<String, dynamic> map) {
    final rawRating = map['rating'] as int?;
    return Book(
      id: map['id'] as int?,
      title: map['title'] as String,
      author: map['author'] as String? ?? '',
      coverPath: map['cover_path'] as String?,
      rating: rawRating != null ? rawRating / 10.0 : null,
      notes: map['notes'] as String?,
      readDate: map['read_date'] != null
          ? DateTime.tryParse(map['read_date'] as String)
          : null,
      startDate: DateTime.parse(map['start_date'] as String),
      status: BookStatus.fromString(map['status'] as String? ?? 'reading'),
      abandonedAt: map['abandoned_at'] != null
          ? DateTime.tryParse(map['abandoned_at'] as String)
          : null,
      finishedAt: map['finished_at'] != null
          ? DateTime.tryParse(map['finished_at'] as String)
          : null,
      readCount: map['read_count'] as int? ?? 1,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  /// 转换为数据库 Map（V3.0: rating 从 double 转 int*10 存储）
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'author': author,
      if (coverPath != null) 'cover_path': coverPath,
      if (rating != null) 'rating': (rating! * 10).round(),
      if (notes != null) 'notes': notes,
      if (readDate != null) 'read_date': _formatDate(readDate!),
      'start_date': _formatDate(startDate),
      'status': status.value,
      if (abandonedAt != null) 'abandoned_at': abandonedAt!.toIso8601String(),
      if (finishedAt != null) 'finished_at': finishedAt!.toIso8601String(),
      'read_count': readCount,
    };
  }

  /// 创建副本
  Book copyWith({
    int? id,
    String? title,
    String? author,
    String? coverPath,
    double? rating,
    String? notes,
    DateTime? readDate,
    DateTime? startDate,
    BookStatus? status,
    DateTime? abandonedAt,
    DateTime? finishedAt,
    int? readCount,
    DateTime? createdAt,
    bool clearId = false,
    bool clearReadDate = false,
    bool clearRating = false,
    bool clearNotes = false,
    bool clearCoverPath = false,
    bool clearAuthor = false,
  }) {
    return Book(
      id: clearId ? null : (id ?? this.id),
      title: title ?? this.title,
      author: clearAuthor ? '' : (author ?? this.author),
      coverPath: clearCoverPath ? null : (coverPath ?? this.coverPath),
      rating: clearRating ? null : (rating ?? this.rating),
      notes: clearNotes ? null : (notes ?? this.notes),
      readDate: clearReadDate ? null : (readDate ?? this.readDate),
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      abandonedAt: abandonedAt ?? this.abandonedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      readCount: readCount ?? this.readCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Book(id: $id, title: $title, status: ${status.value}, author: $author, readCount: $readCount)';

  /// 格式化日期为 YYYY-MM-DD
  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
