/// 筛选状态（V3.0 新增 — 统计页 & 分享页共享）
class FilterState {
  /// null = 全部年份（Pro版专属）
  int? selectedYear;

  /// null = 无月份筛选（1-12 有值）
  int? selectedMonth;

  /// 全局 feature flag
  bool isPro;

  FilterState({
    this.selectedYear,
    this.selectedMonth,
    this.isPro = false,
  });

  /// 当前是否显示进度环（仅当年+无月份时显示）
  bool get showProgressRing =>
      selectedYear == DateTime.now().year && selectedMonth == null;

  /// 是否为全部年份模式（Pro 全生涯）
  bool get isAllYears => selectedYear == null;

  /// 是否有月份筛选
  bool get hasMonth => selectedMonth != null;

  /// 动态标题
  String get dynamicTitle {
    final year = selectedYear;
    final month = selectedMonth;

    if (year == null && month == null) return '📚 我的阅读生涯';
    if (year == DateTime.now().year && month == null) return '📚 $year 读书进度条';
    if (year != null && month == null) return '📚 $year 读书进度条';
    if (year == null && month != null) return '📚 我的阅读生涯 · ${month}月';
    return '📚 $year · $month月';
  }

  /// 复制
  FilterState copyWith({
    int? Function()? selectedYear,
    int? Function()? selectedMonth,
    bool? isPro,
  }) {
    return FilterState(
      selectedYear: selectedYear != null ? selectedYear() : this.selectedYear,
      selectedMonth: selectedMonth != null ? selectedMonth() : this.selectedMonth,
      isPro: isPro ?? this.isPro,
    );
  }
}
