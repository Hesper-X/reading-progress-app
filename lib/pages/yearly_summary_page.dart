import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/book_repository.dart';
import '../databases/database_helper.dart';
import '../theme/colors.dart';
import '../providers/books_provider.dart';

/// 年度总结页（深色主题，Pro 功能）— 按设计稿 09 年度总结.html 实现
class YearlySummaryPage extends StatefulWidget {
  const YearlySummaryPage({super.key});

  @override
  State<YearlySummaryPage> createState() => _YearlySummaryPageState();
}

class _YearlySummaryPageState extends State<YearlySummaryPage> {
  int _selectedYear = DateTime.now().year;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>>? _monthlyTrend;
  List<Map<String, dynamic>>? _topAuthors;
  Map<String, dynamic>? _favoriteBook;
  List<Map<String, dynamic>>? _yearList;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = BookRepository(DatabaseHelper.instance);
    final stats = await repo.getYearlyCycleStats(_selectedYear);
    final totalDays = await repo.getYearlyReadingDays(_selectedYear);
    final monthly = await repo.getMonthlyTrend();
    final authors = await repo.getTopAuthors(year: _selectedYear, limit: 5);
    final favBook = await repo.getFavoriteBook(_selectedYear);
    final yearlyCmp = await repo.getYearlyComparison();
    final years = yearlyCmp.map((e) => e['year'] as String).toSet().toList();

    setState(() {
      _stats = Map<String, dynamic>.from(stats)..['total_days'] = totalDays;
      _monthlyTrend = monthly;
      _topAuthors = authors;
      _favoriteBook = favBook;
      _yearList = years.map((y) => {'year': y, 'title': '${y}年'}).toList();
    });
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: '我的 ${_selectedYear} 年度读书总结'),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Text('←', style: TextStyle(fontSize: 24, color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '年度总结',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _share,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: _stats == null
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // === 年份切换 ===
                      if (_yearList != null && _yearList!.length > 1)
                        SizedBox(
                          height: 36,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _yearList!.map((yearData) {
                              final year = int.tryParse(yearData['year'] as String) ?? _selectedYear;
                              final isSelected = year == _selectedYear;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(yearData['year'] as String),
                                  selected: isSelected,
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() => _selectedYear = year);
                                      _loadData();
                                    }
                                  },
                                  selectedColor: const Color(0xFFFFD700),
                                  labelStyle: TextStyle(
                                    color: isSelected ? AppColors.darkBg : Colors.white70,
                                  ),
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // === Report Header ===
                      const Center(
                        child: Column(
                          children: [
                            Text(
                              '2026',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xB3FFFFFF),
                                letterSpacing: 4,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '年度读书总结',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '这一年，你与书为伴',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xCCFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // === Stats Grid（2x2）===
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: _StatItem(
                              icon: '📖',
                              value: '${_stats!['total_books'] ?? 0}',
                              label: '累计读书（本）',
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _StatItem(
                              icon: '📅',
                              value: '${_stats!['total_days'] ?? 0}',
                              label: '阅读天数',
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _StatItem(
                              icon: '⭐',
                              value: '${_topAuthors?.length ?? 0}',
                              label: '最爱作者（人数）',
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _StatItem(
                              icon: '🏆',
                              value: '${_stats!['avg_rating'] ?? "-"}',
                              label: '平均评分（书籍）',
                          )),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // === 年度最爱 ===
                      _SectionTitle(icon: '⭐', title: '年度最爱'),
                      const SizedBox(height: 12),
                      _buildFavoriteBook(),
                      const SizedBox(height: 24),

                      // === 月度趋势 ===
                      _SectionTitle(icon: '📈', title: '月度趋势'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: SizedBox(
                          height: 140,
                          child: _buildChart(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // === 最爱作者 ===
                      if (_topAuthors != null && _topAuthors!.isNotEmpty) ...[
                        _SectionTitle(icon: '✍️', title: '最爱作者'),
                        const SizedBox(height: 12),
                        ..._topAuthors!.asMap().entries.map((entry) {
                          final index = entry.key;
                          final author = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Text('👨‍💼', style: TextStyle(fontSize: 24)),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '读了 ${author['count']} 本',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xB3FFFFFF),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        author['author'] as String,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                      const SizedBox(height: 24),

                      // === 分享按钮 ===
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _share,
                          icon: const Text('📤', style: TextStyle(fontSize: 16)),
                          label: const Text(
                            '分享我的年度总结',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.primary.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFavoriteBook() {
    if (_favoriteBook == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        child: const Center(
          child: Text('暂无数据', style: TextStyle(color: Color(0x99FFFFFF))),
        ),
      );
    }

    final book = _favoriteBook!;
    final rating = book['rating'];
    final author = book['author'] as String?;
    final title = book['title'] as String? ?? '';
    // rating 显示为星星数量
    final starCount = (rating as int?) ?? 0;
    final stars = '⭐' * starCount.clamp(0, 5);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFC700)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('📗', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  stars.isNotEmpty ? stars : '评分 $starCount',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xCC1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                if (author != null && author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    author,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xB31A1A2E),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final currentMonth = DateTime.now().month;
    final monthMap = <int, int>{};
    for (int i = 1; i <= 12; i++) monthMap[i] = 0;
    if (_monthlyTrend != null) {
      for (final row in _monthlyTrend!) {
        final month = int.tryParse(row['month'] as String? ?? '0') ?? 0;
        final count = (row['count'] as int?) ?? 0;
        if (month >= 1 && month <= 12) monthMap[month] = count;
      }
    }

    final maxVal = monthMap.values.reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal > 0 ? maxVal.toDouble() : 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(12, (i) {
        final month = i + 1;
        final count = monthMap[month] ?? 0;
        final isPastOrCurrent = month <= currentMonth;
        // 可用高度 = 容器高度140 - (顶部标签18 + 月份标签16) = 106
        final barHeight = count > 0 ? (count / chartMax) * 86.0 : 0.0;

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (count > 0)
                Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 2),
              Container(
                height: barHeight.clamp(4.0, 86.0),
                decoration: BoxDecoration(
                  gradient: isPastOrCurrent
                      ? const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                        )
                      : null,
                  color: isPastOrCurrent ? null : Colors.white.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${month}月',
                style: TextStyle(
                  fontSize: 10,
                  color: isPastOrCurrent
                      ? const Color(0x99FFFFFF)
                      : const Color(0x66FFFFFF),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

/// 统计卡片项
class _StatItem extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFFFFD700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xB3FFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

/// 分区标题
class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
