/// 阅读统计模型
class ReadingStats {
  /// 当年已读完成数量
  final int currentYearFinished;

  /// 当月在读数量
  final int currentMonthReading;

  /// 月度趋势（月份 -> 数量）
  final Map<int, int> monthlyTrend;

  /// 平均阅读周期（天）
  final double? avgCycleDays;

  /// 最快阅读周期（天）
  final int? fastestCycleDays;

  /// 最慢阅读周期（天）
  final int? slowestCycleDays;

  /// 最爱作者 TOP5（作者名 -> 数量）
  final List<AuthorStat> topAuthors;

  /// 平均评分
  final double? avgRating;

  const ReadingStats({
    this.currentYearFinished = 0,
    this.currentMonthReading = 0,
    this.monthlyTrend = const {},
    this.avgCycleDays,
    this.fastestCycleDays,
    this.slowestCycleDays,
    this.topAuthors = const [],
    this.avgRating,
  });
}

/// 作者统计
class AuthorStat {
  final String author;
  final int count;

  const AuthorStat({required this.author, required this.count});
}

/// 年度对比数据
class YearlyComparison {
  final int year;
  final int count;
  final double? avgCycle;

  const YearlyComparison({
    required this.year,
    required this.count,
    this.avgCycle,
  });
}

/// 阅读生涯统计数据
class CareerStats {
  final int totalBooks;
  final int totalDays;
  final int authorCount;
  final double? avgRating;
  final DateTime? firstReadDate;
  final int? longestStreak;
  final DateTime? streakStart;
  final DateTime? streakEnd;
  final double? avgCycleDays;
  final List<YearlyComparison> yearlyComparison;
  final List<AuthorStat> topAuthors;

  const CareerStats({
    this.totalBooks = 0,
    this.totalDays = 0,
    this.authorCount = 0,
    this.avgRating,
    this.firstReadDate,
    this.longestStreak,
    this.streakStart,
    this.streakEnd,
    this.avgCycleDays,
    this.yearlyComparison = const [],
    this.topAuthors = const [],
  });
}
