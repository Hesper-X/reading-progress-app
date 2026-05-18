/// 筛选状态（V3.0 新增 — 统计页 & 分享页共享）
class FilterState {
  /// null = 全部年份（Pro版专属）
  int? selectedYear;

  /// null = 全部月份（月份下拉选中「全部」时触发）
  int? selectedMonth;

  /// 全局 feature flag
  bool isPro;

  /// V3.1 新增：是否从统计页「我的阅读生涯」跳转到分享页
  bool fromReadingLife;

  FilterState({
    this.selectedYear,
    this.selectedMonth,
    this.isPro = false,
    this.fromReadingLife = false,
  });

  /// 当前是否显示进度环（仅当年+月份「全部」时显示）
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
    bool? fromReadingLife,
  }) {
    return FilterState(
      selectedYear: selectedYear != null ? selectedYear() : this.selectedYear,
      selectedMonth: selectedMonth != null ? selectedMonth() : this.selectedMonth,
      isPro: isPro ?? this.isPro,
      fromReadingLife: fromReadingLife ?? this.fromReadingLife,
    );
  }
}
