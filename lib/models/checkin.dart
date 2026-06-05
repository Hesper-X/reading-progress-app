/// 打卡详情数据模型（V3.5）
/// 对应 checkin_details 表，每次打卡一条记录
class CheckinDetail {
  final int? id;
  final int bookId;
  final String checkinDate; // 'YYYY-MM-DD'
  final int? durationMin; // 阅读时长（分钟，选填）
  final String? note; // 笔记（选填，上限200字）
  final DateTime? createdAt;

  const CheckinDetail({
    this.id,
    required this.bookId,
    required this.checkinDate,
    this.durationMin,
    this.note,
    this.createdAt,
  });

  // ============ 派生数据 ============

  /// 格式化时长：如 "1小时30分钟"
  String get formattedDuration {
    if (durationMin == null) return '';
    final h = durationMin! ~/ 60;
    final m = durationMin! % 60;
    if (h == 0 && m == 0) return '';
    if (h == 0) return '${m}分钟';
    if (m == 0) return '${h}小时';
    return '${h}小时${m}分钟';
  }

  /// 格式化日期：如 "2026年6月28日"
  String get formattedDate {
    final parts = checkinDate.split('-');
    if (parts.length != 3) return checkinDate;
    return '${int.parse(parts[0])}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  /// 获取星期几
  String get weekday {
    final parts = checkinDate.split('-');
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[date.weekday - 1];
  }

  // ============ 序列化 ============

  factory CheckinDetail.fromMap(Map<String, dynamic> map) {
    return CheckinDetail(
      id: map['id'] as int?,
      bookId: map['book_id'] as int,
      checkinDate: map['checkin_date'] as String,
      durationMin: map['duration_min'] as int?,
      note: map['note'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'book_id': bookId,
      'checkin_date': checkinDate,
      if (durationMin != null) 'duration_min': durationMin,
      if (note != null && note!.isNotEmpty) 'note': note,
    };
  }

  CheckinDetail copyWith({
    int? id,
    int? bookId,
    String? checkinDate,
    int? durationMin,
    String? note,
    DateTime? createdAt,
    bool clearDuration = false,
    bool clearNote = false,
  }) {
    return CheckinDetail(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      checkinDate: checkinDate ?? this.checkinDate,
      durationMin: clearDuration ? null : (durationMin ?? this.durationMin),
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'CheckinDetail(id: $id, bookId: $bookId, date: $checkinDate, durationMin: $durationMin)';
}

/// 某日打卡汇总（用于打卡详情 Dialog 和日历展示）
class CheckinDaySummary {
  /// 该日所有打卡记录
  final List<CheckinDetail> details;

  /// 该日书籍名称映射（bookId → title）
  final Map<int, String> bookTitles;

  CheckinDaySummary({
    required this.details,
    required this.bookTitles,
    this.streakDays = 0,
  });

  /// 当日总时长（分钟）
  int get totalMinutes =>
      details.fold(0, (sum, d) => sum + (d.durationMin ?? 0));

  /// 格式化总时长
  String get formattedTotalDuration {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0 && m == 0) return '';
    if (h == 0) return '${m}分钟';
    if (m == 0) return '${h}小时';
    return '${h}小时${m}分钟';
  }

  /// 连续阅读天数（截至当天）
  final int streakDays;

  /// 该日是否有笔记
  bool get hasNote =>
      details.any((d) => d.note != null && d.note!.isNotEmpty);
}
