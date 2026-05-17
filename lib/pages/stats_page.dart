import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../providers/filter_provider.dart';
import '../theme/colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
          final favoriteBooks = _computeFavoriteBooks(scopeList);
          final longest = _computeLongest(scopeList);
          final shortest = _computeShortest(scopeList);
          final readList = _computeReadList(scopeList);
          final favoriteAuthors = _computeFavoriteAuthors(scopeList);
          final currentMonthCount = _computeCurrentMonthCount(scopeList);
          final lastMonthCount = _computeLastMonthCount(scopeList);
          final diff = currentMonthCount - lastMonthCount;

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
                  onYearTap: () => _showYearPicker(context, filterProvider, doneBooks),
                  onMonthTap: () => _showMonthPicker(context, filterProvider, doneBooks),
                ),
                const SizedBox(height: 20),

                // === 2. 柱状图 ===
                if (filter.selectedYear != null) ...[
                  const Text('月度趋势', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF212529))),
                  const SizedBox(height: 8),
                  _ChartSection(year: filter.selectedYear!, data: monthlyTrend),
                  const SizedBox(height: 20),
                ],

                if (filter.selectedYear == null && filter.isPro) ...[
                  _SectionTitle(icon: '📊', text: '全部·各年对比'),
                  const SizedBox(height: 8),
                  _YearlyChart(data: monthlyTrend),
                  const SizedBox(height: 20),
                ],

                // === 3. 最爱书籍 Top3 ===
                Row(children: [
                  SvgPicture.asset('assets/icons/stat-icon-fav-books.svg', width: 14, height: 14),
                  const SizedBox(width: 6),
                  const Text('最爱书籍', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xCC212529))),
                ]),
                const SizedBox(height: 8),
                _FavoriteBooksSection(data: favoriteBooks),
                const SizedBox(height: 20),

                // === 4. 最长与最短 ===
                _SectionTitle(icon: '⏱', text: '读书时间·最长与最短'),
                const SizedBox(height: 8),
                _LongestShortestSection(longest: longest, shortest: shortest),
                const SizedBox(height: 20),

                // === 5. 已读书单 ===
                // 标题由 _ReadListSection 内部渲染
                _ReadListSection(books: readList),
                const SizedBox(height: 20),

                // === 6. 最爱作者 Top3 ===
                // 标题由 _FavoriteAuthorsSection 内部渲染
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
    final book = valid.first;
    return {'title': book.title, 'author': book.author, 'days': book.readingCycleDays, 'startDate': book.formattedStartDate, 'endDate': book.formattedReadDate};
  }

  Map<String, dynamic>? _computeShortest(List<Book> books) {
    final valid = books.where((b) => b.readingCycleDays != null && b.readingCycleDays! > 0).toList();
    if (valid.isEmpty) return null;
    valid.sort((a, b) => a.readingCycleDays!.compareTo(b.readingCycleDays!));
    final book = valid.first;
    return {'title': book.title, 'author': book.author, 'days': book.readingCycleDays, 'startDate': book.formattedStartDate, 'endDate': book.formattedReadDate};
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

  void _showYearPicker(BuildContext context, FilterProvider fp, List<Book> allBooks) {
    final now = DateTime.now();
    final years = allBooks.map((b) => b.readDate?.year).where((y) => y != null).toSet().toList()..sort((a, b) => b!.compareTo(a!));
    if (!years.contains(now.year)) years.insert(0, now.year);
    final cur = fp.state.selectedYear;
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.only(top: 12, bottom: 8), child: Text('选择年份', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        const Divider(height: 1),
        ...years.map((y) => ListTile(title: Text('${y}年', textAlign: TextAlign.center), trailing: y == cur ? const Icon(Icons.check, size: 18, color: Color(0xFFFF6B6B)) : null, onTap: () { fp.setYear(y!); Navigator.pop(ctx); })),
      ])),
    );
  }

  void _showMonthPicker(BuildContext context, FilterProvider fp, List<Book> allBooks) {
    final now = DateTime.now();
    final items = [_MonthOption(label: '全部', value: null), ...List.generate(now.month, (i) => _MonthOption(label: '${i + 1}月', value: i + 1))];
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Padding(padding: EdgeInsets.only(top: 12, bottom: 8), child: Text('选择月份', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
        const Divider(height: 1),
        ...items.map((item) => ListTile(
          title: Text(item.label, textAlign: TextAlign.center),
          trailing: fp.state.selectedMonth == item.value ? const Icon(Icons.check, size: 18, color: Color(0xFFFF6B6B)) : null,
          onTap: () { if (item.value == null) { fp.setMonth(null); } else { fp.setMonth(item.value!); } Navigator.pop(ctx); },
        )),
      ])),
    );
  }
}

class _MonthOption {
  final String label;
  final int? value;
  const _MonthOption({required this.label, this.value});
}

// ============ Pro 提示条 ============

class _ProTipBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFD4D4)),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('基础版 · ${now.year} 年度统计', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B))),
          const SizedBox(height: 2),
          const Text('升级 Pro 查看全部年份阅读生涯', style: TextStyle(fontSize: 11, color: Color(0xFFE8590C))),
        ])),
        GestureDetector(onTap: () => Navigator.pushNamed(context, '/pro'), child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: const Color(0xFFFF6B6B), borderRadius: BorderRadius.circular(16)),
          child: const Text('升级', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
        )),
      ]),
    );
  }
}

// ============ 模块标题 ============

class _SectionTitle extends StatelessWidget {
  final String icon;
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
  final VoidCallback onYearTap;
  final VoidCallback onMonthTap;

  const _TopCards({
    required this.currentMonthCount,
    required this.diff,
    required this.yearTotal,
    required this.yearlyGoal,
    required this.selectedYear,
    required this.selectedMonth,
    required this.onYearTap,
    required this.onMonthTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 左卡：年度统计数据（年份可下拉）
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onYearTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.15))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(selectedYear != null ? '$selectedYear' : '全部', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B))),
                        const SizedBox(width: 2),
                        const Text('▾', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$yearTotal 本', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFFF6B6B), height: 1)),
                const SizedBox(height: 6),
                Row(children: [
                  const Text('已读', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF51CF66))),
                  const Text(' · ', style: TextStyle(fontSize: 11, color: Color(0xFF868E96))),
                  Text('目标 ${yearlyGoal > 0 ? yearlyGoal : 0} 本', style: const TextStyle(fontSize: 11, color: Color(0xFF868E96))),
                ]),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // 右卡：月份统计数据
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onMonthTap,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFF6B6B).withValues(alpha: 0.15))),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(selectedMonth != null ? '$selectedMonth月' : '全部', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B))),
                        const SizedBox(width: 2),
                        const Text('▾', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B))),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('$currentMonthCount 本', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Color(0xFFFF6B6B), height: 1)),
                const SizedBox(height: 6),
                Row(children: [
                  Text(diff >= 0 ? '↑' : '↓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: diff >= 0 ? const Color(0xFF51CF66) : const Color(0xFFFA5252))),
                  const SizedBox(width: 4),
                  Text(diff >= 0 ? '较上月 +$diff 本' : '较上月 $diff 本', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: diff >= 0 ? const Color(0xFF51CF66) : const Color(0xFFFA5252))),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============ 柱状图 ============

class _ChartSection extends StatelessWidget {
  final int year;
  final Map<int, int> data;

  const _ChartSection({required this.year, required this.data});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentMonth = now.month;
    final maxVal = data.values.reduce((a, b) => a > b ? a : b);
    final chartMaxY = maxVal > 0 ? maxVal + 2.0 : 10.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('$year 年读书数量（月份）', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF212529))),
            Row(children: [
              Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFF6B6B))),
              const SizedBox(width: 4),
              const Text('已读', style: TextStyle(fontSize: 11, color: Color(0xFF868E96))),
            ]),
          ]),
          const SizedBox(height: 12),
          SizedBox(height: 150, child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(12, (i) {
              final month = i + 1;
              final count = data[month] ?? 0;
              final isPastOrCurrent = month <= currentMonth;
              final barHeight = (count / chartMaxY * 140.0);
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: (i == 0 || i == 11) ? 2.0 : 3.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (count > 0)
                        Text('$count', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                      const SizedBox(height: 2),
                      Container(
                        width: double.infinity,
                        height: barHeight.clamp(4.0, 140.0),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
                          gradient: isPastOrCurrent && count > 0
                              ? const LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)])
                              : null,
                          color: count > 0 && !isPastOrCurrent ? const Color(0xFFE9ECEF) : (count == 0 ? const Color(0xFFE9ECEF) : null),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('$month', style: TextStyle(fontSize: 10, color: isPastOrCurrent ? AppColors.textSecondary : AppColors.textMuted)),
                    ],
                  ),
                ),
              );
            }),
          )),
        ],
      ),
    );
  }
}

// ============ 年度对比柱状图（Pro） ============

class _YearlyChart extends StatelessWidget {
  final Map<int, int> data;

  const _YearlyChart({required this.data});

  @override
  Widget build(BuildContext context) {
    // 简化：按年份列出
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: const Center(child: Text('生日模式柱状图（Pro）', style: TextStyle(fontSize: 14, color: AppColors.textMuted))),
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
    return Column(
      children: data.map((d) {
        final index = data.indexOf(d);
        final rank = index + 1;
        final isLast = rank >= data.length;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: !isLast ? const Border(bottom: BorderSide(color: Color(0xFFF1F3F5))) : null,
          ),
          child: Row(
            children: [
              // 序号圆圈
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: rank == 1 ? const Color(0xFFFF6B6B) : (rank == 2 ? const Color(0xFF51CF66) : const Color(0xFF339AF0)),
                ),
                child: Center(child: Text('$rank', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))),
              ),
              const SizedBox(width: 10),
              // 书名 + 作者
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text('《${d['title']}》', style: const TextStyle(fontSize: 14, color: Color(0xFF212529)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Text('${d['author']}', style: const TextStyle(fontSize: 12, color: Color(0xFF868E96))),
                  ],
                ),
              ),
              // 读了n次
              Text('读了 ${d['count']} 次', style: const TextStyle(fontSize: 11, color: Color(0xFFADB5BD))),
            ],
          ),
        );
      }).toList(),
    );
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
    return Column(
      children: [
        _TimeCompareItem(label: '最长', labelColor: const Color(0xFFFF6B6B), daysColor: const Color(0xFFFF6B6B), icon: '📘', book: longest!),
        Container(height: 1, color: const Color(0xFFF1F3F5)),
        _TimeCompareItem(label: '最短', labelColor: const Color(0xFF51CF66), daysColor: const Color(0xFF51CF66), icon: '📗', book: shortest!),
      ],
    );
  }
}

class _TimeCompareItem extends StatelessWidget {
  final String label;
  final Color labelColor;
  final Color daysColor;
  final String icon;
  final Map<String, dynamic> book;

  const _TimeCompareItem({required this.label, required this.labelColor, required this.daysColor, required this.icon, required this.book});

  @override
  Widget build(BuildContext context) {
    final title = book['title'] as String;
    final days = book['days'];
    final startDate = book['startDate'] as String? ?? '';
    final endDate = book['endDate'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$icon $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text('《$title》',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF212529)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text('共读 $days 天', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: daysColor)),
            ],
          ),
          if (startDate.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('$startDate → $endDate', style: const TextStyle(fontSize: 12, color: Color(0xFF868E96))),
            ),
        ],
      ),
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
    // 提取月份标签：2026年5月
    String formatMonth(DateTime d) => '${d.year}年${d.month}月';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题行
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              SvgPicture.asset('assets/icons/stat-icon-read-list.svg', width: 14, height: 14),
              const SizedBox(width: 4),
              const Text('已读书单', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF212529))),
            ]),
            Text('共 ${books.length} 本', style: const TextStyle(fontSize: 12, color: Color(0xFFADB5BD), fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 10),
        // 书籍列表
        ...List.generate(books.length > 10 ? 10 : books.length, (i) {
          final book = books[i];
          final isLast = i >= (books.length > 10 ? 9 : books.length - 1);
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: !isLast ? const Border(bottom: BorderSide(color: Color(0xFFF1F3F5))) : null,
            ),
            child: Row(
              children: [
                // 灰色序号圆圈
                Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFCED4DA)),
                  child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))),
                ),
                const SizedBox(width: 10),
                // 书名
                Text('《${book.title}》', style: const TextStyle(fontSize: 14, color: Color(0xFF212529)),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(width: 10),
                // 作者 · 年月
                Expanded(
                  child: Text('${book.author} · ${book.readDate != null ? formatMonth(book.readDate!) : ""}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF868E96)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          );
        }),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          SvgPicture.asset('assets/icons/stat-icon-fav-authors.svg', width: 14, height: 14),
          const SizedBox(width: 4),
          const Text('最爱作者', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF212529))),
        ]),
        const SizedBox(height: 10),
        ...List.generate(data.length > 3 ? 3 : data.length, (i) {
          final d = data[i];
          final isLast = i >= ((data.length > 3 ? 3 : data.length) - 1);
          final rankColors = [const Color(0xFFFF6B6B), const Color(0xFF51CF66), const Color(0xFF339AF0)];
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              border: !isLast ? const Border(bottom: BorderSide(color: Color(0xFFF1F3F5))) : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: rankColors[i > 2 ? 2 : i]),
                  child: Center(child: Text('${i + 1}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(d['author'] as String, style: const TextStyle(fontSize: 14, color: Color(0xFF212529)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text('读了 ${d['count']} 本', style: const TextStyle(fontSize: 11, color: Color(0xFFADB5BD))),
              ],
            ),
          );
        }),
      ],
    );
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

/// 统计页专用SVG图标16px
class _StatSvgIcon16 extends StatelessWidget {
  final String svg;
  const _StatSvgIcon16({required this.svg});

  static const _favBooks = ['M12 2L2 7l10 5 10-5-10-5z', 'M2 17l10 5 10-5', 'M2 12l10 5 10-5'];

  @override
  Widget build(BuildContext context) {
    final paths = _favBooks;
    return SizedBox(width: 16, height: 16, child: CustomPaint(painter: _SvgStrokePainter(paths: paths)));
  }
}

class _SvgStrokePainter extends CustomPainter {
  final List<String> paths;
  _SvgStrokePainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF6B6B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    for (final d in paths) {
      final p = Path();
      final segs = d.split(RegExp(r'(?=[MLCZmlcz])'));
      for (final seg in segs) {
        if (seg.isEmpty) continue;
        final cmd = seg[0];
        final nums = seg.substring(1).trim().split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty).map(double.parse).toList();
        switch (cmd) {
          case 'M': p.moveTo(nums[0], nums[1]); break;
          case 'L': p.lineTo(nums[0], nums[1]); break;
          case 'C': p.cubicTo(nums[0], nums[1], nums[2], nums[3], nums[4], nums[5]); break;
          case 'Z': case 'z': p.close(); break;
        }
      }
      canvas.drawPath(p, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
