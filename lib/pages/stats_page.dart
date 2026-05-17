import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../providers/filter_provider.dart';
import '../theme/colors.dart';

/// 统计页（V3.0：6栏位 + 柱状图修复 + Pro提示 + SVG标题 + 序号圆圈）
class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1),
        ),
        title: const Text(
          '阅读统计',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: Consumer2<BooksProvider, FilterProvider>(
        builder: (context, booksProvider, filterProvider, _) {
          if (booksProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final filter = filterProvider.state;
          final doneBooks = booksProvider.doneBooks;

          // 按筛选范围过滤
          final scopeBooks = _filterBooks(doneBooks, filter.selectedYear, filter.selectedMonth);
          final scopeList = scopeBooks.toList();

          // 各项计算
          final monthlyTrend = _computeMonthlyTrend(scopeList);
          final yearlyTrend = _computeYearlyTrend(doneBooks);
          final favoriteBooks = _computeFavoriteBooks(scopeList);
          final longest = _computeLongest(scopeList);
          final shortest = _computeShortest(scopeList);
          final readList = _computeReadList(scopeList);
          final favoriteAuthors = _computeFavoriteAuthors(scopeList);
          final currentMonthCount = _computeCurrentMonthCount(scopeList);
          final lastMonthCount = _computeLastMonthCount(scopeList);
          final diff = currentMonthCount - lastMonthCount;

          // 判断当前是否为"全部年份"模式（年模式）
          final isYearMode = filter.selectedYear == null && filter.isPro;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pro提示条（基础版显示）
                if (!filter.isPro)
                  _ProTipBar(),

                // === 1. 顶部统计卡片 ===
                _TopCards(
                  currentMonthCount: currentMonthCount,
                  diff: diff,
                  yearTotal: scopeList.length,
                  yearlyGoal: booksProvider.yearlyGoal,
                  selectedYear: filter.selectedYear,
                  selectedMonth: filter.selectedMonth,
                  isYearMode: isYearMode,
                  onMonthTap: isYearMode
                      ? () => _showYearPicker(context, filterProvider)
                      : null,
                ),
                const SizedBox(height: 20),

                // === 2. 柱状图 ===
                _ChartSection(
                  isYearMode: isYearMode,
                  year: filter.selectedYear,
                  monthlyData: monthlyTrend,
                  yearlyData: yearlyTrend,
                ),
                const SizedBox(height: 20),

                // === 3. 最爱书籍 Top3 ===
                _SectionTitle(icon: '📖', text: '最爱书籍'),
                const SizedBox(height: 8),
                _FavoriteBooksSection(data: favoriteBooks),
                const SizedBox(height: 20),

                // === 4. 最长与最短 ===
                _SectionTitle(icon: '⏱', text: '读书时间·最长与最短'),
                const SizedBox(height: 8),
                _LongestShortestSection(longest: longest, shortest: shortest),
                const SizedBox(height: 20),

                // === 5. 已读书单 ===
                _SectionTitle(icon: '📉', text: '已读书单'),
                const SizedBox(height: 8),
                _ReadListSection(books: readList),
                const SizedBox(height: 20),

                // === 6. 最爱作者 Top3 ===
                _SectionTitle(icon: '👥', text: '最爱作者'),
                const SizedBox(height: 8),
                _FavoriteAuthorsSection(data: favoriteAuthors),
                const SizedBox(height: 20),

                // === 底部按钮（Pro版「我的阅读生涯」） ===
                if (filter.isPro)
                  _CareerButton(
                    onTap: () {
                      // 跳转分享Tab，切到全部年份
                      filterProvider.switchToAllYears();
                      Navigator.pushNamed(context, '/share');
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  // ============ 年份选择弹窗（Pro 版新增"全部年份"选项） ============

  void _showYearPicker(BuildContext context, FilterProvider filterProvider) {
    final years = filterProvider.availableYears;
    final currentSelection = filterProvider.selectedYear;

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择年份', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              // "全部年份"选项（Pro版专有）
              if (filterProvider.isPro) ...[
                GestureDetector(
                  onTap: () {
                    filterProvider.setYear(null);
                    filterProvider.setMonth(null);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: currentSelection == null
                          ? const Color(0xFFFF6B6B).withValues(alpha: 0.1)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 18,
                          color: currentSelection == null ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '全部年份（生涯数据）',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: currentSelection == null ? FontWeight.w600 : FontWeight.w400,
                            color: currentSelection == null ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        if (currentSelection == null) ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 18, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
              ...years.map((year) {
                final isSelected = year == currentSelection;
                return GestureDetector(
                  onTap: () {
                    filterProvider.setYear(year);
                    filterProvider.setMonth(null);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: isSelected
                          ? const Color(0xFFFF6B6B).withValues(alpha: 0.1)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$year年',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        if (isSelected) ...[
                          const Spacer(),
                          const Icon(Icons.check, size: 18, color: AppColors.primary),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F3F5),
                    foregroundColor: AppColors.textSecondary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('取消'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ============ 数据计算函数 ============

  Iterable<Book> _filterBooks(List<Book> books, int? year, int? month) {
    Iterable<Book> result = books;
    if (year != null) result = result.where((b) => b.readDate?.year == year);
    if (month != null) result = result.where((b) => b.readDate?.month == month);
    return result;
  }

  Map<int, int> _computeMonthlyTrend(List<Book> books) {
    final trend = <int, int>{};
    for (int i = 1; i <= 12; i++) { trend[i] = 0; }
    for (final b in books) {
      if (b.readDate != null) {
        trend[b.readDate!.month] = (trend[b.readDate!.month] ?? 0) + 1;
      }
    }
    return trend;
  }

  Map<int, int> _computeYearlyTrend(List<Book> books) {
    final trend = <int, int>{};
    for (final b in books) {
      if (b.readDate != null) {
        final y = b.readDate!.year;
        trend[y] = (trend[y] ?? 0) + 1;
      }
    }
    return trend;
  }

  List<Map<String, dynamic>> _computeFavoriteBooks(List<Book> books) {
    final grouped = <String, List<Book>>{};
    for (final b in books) {
      grouped.putIfAbsent(b.title, () => []).add(b);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.length.compareTo(a.value.length);
        if (cmp != 0) return cmp;
        final aRating = a.value.fold<double>(0, (s, e) => s + (e.rating ?? 0));
        final bRating = b.value.fold<double>(0, (s, e) => s + (e.rating ?? 0));
        if (aRating != bRating) return bRating.compareTo(aRating);
        final aDate = a.value.first.readDate ?? DateTime(2000);
        final bDate = b.value.first.readDate ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });
    return entries.take(3).map((e) => {
      'title': e.key,
      'author': e.value.first.author,
      'count': e.value.length,
      'rating': e.value.first.rating,
    }).toList();
  }

  Map<String, dynamic>? _computeLongest(List<Book> books) {
    final valid = books.where((b) => b.readingCycleDays != null && b.readingCycleDays! > 0).toList();
    if (valid.isEmpty) return null;
    valid.sort((a, b) => b.readingCycleDays!.compareTo(a.readingCycleDays!));
    return {'title': valid.first.title, 'author': valid.first.author, 'days': valid.first.readingCycleDays};
  }

  Map<String, dynamic>? _computeShortest(List<Book> books) {
    final valid = books.where((b) => b.readingCycleDays != null && b.readingCycleDays! > 0).toList();
    if (valid.isEmpty) return null;
    valid.sort((a, b) => a.readingCycleDays!.compareTo(b.readingCycleDays!));
    return {'title': valid.first.title, 'author': valid.first.author, 'days': valid.first.readingCycleDays};
  }

  List<Book> _computeReadList(List<Book> books) {
    final result = List<Book>.from(books)
      ..sort((a, b) => (b.readDate ?? DateTime(2000)).compareTo(a.readDate ?? DateTime(2000)));
    return result;
  }

  List<Map<String, dynamic>> _computeFavoriteAuthors(List<Book> books) {
    final counts = <String, int>{};
    final ratings = <String, double>{};
    final dates = <String, DateTime>{};
    for (final b in books) {
      if (b.author.isNotEmpty) {
        counts[b.author] = (counts[b.author] ?? 0) + 1;
        final r = b.rating ?? 0;
        ratings[b.author] = (ratings[b.author] ?? 0) + r;
        final d = b.readDate ?? DateTime(2000);
        if (dates[b.author] == null || d.isAfter(dates[b.author]!)) {
          dates[b.author] = d;
        }
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        if (cmp != 0) return cmp;
        final rCmp = (ratings[b.key] ?? 0).compareTo(ratings[a.key] ?? 0);
        if (rCmp != 0) return rCmp;
        return (dates[b.key] ?? DateTime(2000)).compareTo(dates[a.key] ?? DateTime(2000));
      });
    return entries.take(3).map((e) => {'author': e.key, 'count': e.value}).toList();
  }

  int _computeCurrentMonthCount(List<Book> books) {
    final now = DateTime.now();
    return books.where((b) => b.readDate?.month == now.month).length;
  }

  int _computeLastMonthCount(List<Book> books) {
    final lastMonth = DateTime.now().month - 1;
    if (lastMonth < 1) return 0;
    return books.where((b) => b.readDate?.month == lastMonth).length;
  }
}

// ============ Pro 提示条 ============

class _ProTipBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFD43B).withValues(alpha: 0.15), const Color(0xFFFF922B).withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD43B).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('开通Pro查看全生涯数据及分享图',
                style: TextStyle(fontSize: 13, color: Color(0xFFE67700))),
          ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/pro'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B6B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('升级', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 模块标题 ============

class _SectionTitle extends StatelessWidget {
  final String icon; // Emoji，开发实现可用 SVG
  final String text;

  const _SectionTitle({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xCC212529))),
      ],
    );
  }
}

// ============ 顶部统计卡片 ============

class _TopCards extends StatelessWidget {
  final int currentMonthCount;
  final int diff;
  final int yearTotal;
  final int yearlyGoal;
  final int? selectedYear;
  final int? selectedMonth;
  final bool isYearMode;
  final VoidCallback? onMonthTap;

  const _TopCards({
    required this.currentMonthCount,
    required this.diff,
    required this.yearTotal,
    required this.yearlyGoal,
    required this.selectedYear,
    required this.selectedMonth,
    this.isYearMode = false,
    this.onMonthTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左卡：月份统计数据
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFE3E3), Color(0xFFFFD3D3)],
              ),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(selectedMonth != null
                    ? '$selectedMonth月'
                    : (isYearMode ? '全部年份' : '本月'),
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text('$currentMonthCount 本',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1)),
                const SizedBox(height: 6),
                Row(children: [
                  Text(diff >= 0 ? '↑' : '↓',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: diff >= 0 ? AppColors.success : const Color(0xFFFA5252))),
                  const SizedBox(width: 4),
                  Text(diff >= 0 ? '较上月 +$diff 本' : '较上月 $diff 本',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: diff >= 0 ? AppColors.success : const Color(0xFFFA5252))),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 右卡：年度统计数据
        Expanded(
          child: GestureDetector(
            onTap: isYearMode ? onMonthTap : null,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFE3E3), Color(0xFFFFD3D3)],
                ),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(selectedYear != null ? '$selectedYear年' : '全部',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  Text('$yearTotal 本',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary, height: 1)),
                  if (!isYearMode && selectedYear == DateTime.now().year) ...[
                    const SizedBox(height: 6),
                    Text('${yearlyGoal > 0 ? (yearTotal / yearlyGoal * 100).toInt() : 0}% 完成',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.success)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============ 柱状图 ============

class _ChartSection extends StatelessWidget {
  final bool isYearMode;
  final int? year;
  final Map<int, int> monthlyData;
  final Map<int, int> yearlyData;

  const _ChartSection({
    this.isYearMode = false,
    this.year,
    required this.monthlyData,
    required this.yearlyData,
  });

  @override
  Widget build(BuildContext context) {
    if (isYearMode) {
      // 年模式：显示年度趋势（各年份对比）
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: '📊', text: '全部·各年对比'),
          const SizedBox(height: 8),
          _YearChart(data: yearlyData),
        ],
      );
    } else if (year != null) {
      // 月模式：显示12个月
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: '📊', text: '${year}年读书数量（月份）'),
          const SizedBox(height: 8),
          _MonthChart(year: year!, data: monthlyData),
        ],
      );
    } else {
      // 基础版无年份选择：空
      return const SizedBox.shrink();
    }
  }
}

// ============ 月柱状图 ============

class _MonthChart extends StatelessWidget {
  final int year;
  final Map<int, int> data;

  const _MonthChart({required this.year, required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final maxVal = data.values.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxVal > 0 ? maxVal + 2.0 : 10.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(12, (i) {
            final month = i + 1;
            final count = data[month] ?? 0;
            final isPastOrCurrent = month <= currentMonth;
            final barHeight = (count / chartMaxY * 140.0);

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text('$count', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Container(
                    width: 44,
                    height: barHeight.clamp(4.0, 140.0),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                      gradient: isPastOrCurrent && count > 0
                          ? const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                            )
                          : null,
                      color: count > 0 && !isPastOrCurrent
                          ? const Color(0xFFE9ECEF)
                          : (count == 0 ? const Color(0xFFE9ECEF) : null),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('$month', style: TextStyle(fontSize: 10, color: isPastOrCurrent ? AppColors.textSecondary : AppColors.textMuted)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ============ 年度对比柱状图（Pro） ============

class _YearChart extends StatelessWidget {
  final Map<int, int> data;

  const _YearChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.values.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxVal > 0 ? maxVal + 2.0 : 10.0;
    final sortedYears = data.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: SizedBox(
        height: 160,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: sortedYears.map((entry) {
            final count = entry.value;
            final barHeight = (count / chartMaxY * 140.0);

            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text('$count', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Container(
                    width: 44,
                    height: barHeight.clamp(4.0, 140.0),
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                      gradient: const LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${entry.key}', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ============ 最爱书籍 Top3 ============

class _FavoriteBooksSection extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _FavoriteBooksSection({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _EmptyCard(text: '暂无最爱书籍数据');
    }
    final items = data.map((d) => _RankItemData(
      rank: data.indexOf(d) + 1,
      title: d['title'] as String,
      subtitle: '${d['author']} · 读了${d['count']}次',
    )).toList();
    return _RankList(items: items);
  }
}

// ============ 最长与最短 ============

class _LongestShortestSection extends StatelessWidget {
  final Map<String, dynamic>? longest;
  final Map<String, dynamic>? shortest;

  const _LongestShortestSection({required this.longest, required this.shortest});

  @override
  Widget build(BuildContext context) {
    if (longest == null && shortest == null) {
      return _EmptyCard(text: '暂无阅读数据');
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: Row(
        children: [
          Expanded(child: _DurationItem(icon: '📘', label: '最长', book: longest)),
          Container(width: 1, height: 40, color: const Color(0xFFF1F3F5)),
          Expanded(child: _DurationItem(icon: '📗', label: '最短', book: shortest)),
        ],
      ),
    );
  }
}

class _DurationItem extends StatelessWidget {
  final String icon;
  final String label;
  final Map<String, dynamic>? book;

  const _DurationItem({required this.icon, required this.label, required this.book});

  @override
  Widget build(BuildContext context) {
    if (book == null) return const SizedBox();
    return Column(
      children: [
        Text('$icon $label', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Text('《${book!['title']}》', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        Text('${book!['days']}天', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ============ 已读书单 ============

class _ReadListSection extends StatelessWidget {
  final List<Book> books;

  const _ReadListSection({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return _EmptyCard(text: '还没有读完的书');
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: Column(
        children: books.take(10).map((book) => _ReadListItem(book: book)).toList(),
      ),
    );
  }
}

class _ReadListItem extends StatelessWidget {
  final Book book;
  const _ReadListItem({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color(0xFFF1F3F5))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(book.title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (book.formattedReadDate != null)
            Text(book.formattedReadDate!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

// ============ 最爱作者 Top3 ============

class _FavoriteAuthorsSection extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _FavoriteAuthorsSection({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _EmptyCard(text: '暂无最爱作者数据');
    }
    final items = data.map((d) => _RankItemData(
      rank: data.indexOf(d) + 1,
      title: d['author'] as String,
      subtitle: '${d['count']}本',
    )).toList();
    return _RankList(items: items);
  }
}

// ============ 排名列表通用组件 ============

class _RankItemData {
  final int rank;
  final String title;
  final String subtitle;

  _RankItemData({required this.rank, required this.title, required this.subtitle});
}

class _RankList extends StatelessWidget {
  final List<_RankItemData> items;

  const _RankList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: Column(
        children: items.map((item) => _RankCard(item: item, totalCount: items.length)).toList(),
      ),
    );
  }
}

class _RankCard extends StatelessWidget {
  final _RankItemData item;
  final int totalCount;
  const _RankCard({required this.item, this.totalCount = 0});

  @override
  Widget build(BuildContext context) {
    final isLast = item.rank >= totalCount;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: !isLast
            ? const Border(bottom: BorderSide(color: Color(0xFFF1F3F5)))
            : null,
      ),
      child: Row(
        children: [
          // 序号圆圈
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.rank == 1
                  ? const Color(0xFFFF6B6B)
                  : (item.rank == 2
                      ? const Color(0xFF51CF66)
                      : (item.rank == 3
                          ? const Color(0xFF339AF0)
                          : const Color(0xFFCED4DA))),
            ),
            child: Center(
              child: Text('${item.rank}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(item.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 底部按钮 ============

class _CareerButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CareerButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
          ),
          boxShadow: [
            BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: const Center(
          child: Text('📚 我的阅读生涯',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }
}

// ============ 空状态 ============

class _EmptyCard extends StatelessWidget {
  final String text;
  const _EmptyCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: Center(
        child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
      ),
    );
  }
}
