import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../repositories/book_repository.dart';
import '../databases/database_helper.dart';
import '../theme/colors.dart';
import '../models/reading_stats.dart';

/// 阅读生涯页（深色主题，Pro 功能）— 按设计稿 10 阅读生涯.html 实现
class ReadingLifePage extends StatefulWidget {
  const ReadingLifePage({super.key});

  @override
  State<ReadingLifePage> createState() => _ReadingLifePageState();
}

class _ReadingLifePageState extends State<ReadingLifePage> {
  CareerStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = BookRepository(DatabaseHelper.instance);

    final totalBooks = await repo.getTotalFinishedCount();
    final totalDays = await repo.getCareerReadingDays();
    final authorCount = await repo.getDistinctAuthorCount();
    final avgRating = await repo.getOverallAvgRating();
    final firstDate = await repo.getFirstReadDate();
    final avgCycle = await repo.getOverallAvgCycle();
    final yearlyComp = await repo.getYearlyComparison();
    final topAuthors = await repo.getTopAuthors(year: null, limit: 5);

    // 最长连续阅读（单本书从开始到读完的最大天数）
    final longestCycle = await repo.getLongestReadingCycle();
    int longestStreak = 0;
    DateTime? streakStart;
    DateTime? streakEnd;
    if (longestCycle != null) {
      final cycle = longestCycle['cycle'] as num?;
      longestStreak = cycle?.toInt() ?? 0;
      final startStr = longestCycle['start_date'] as String?;
      final endStr = longestCycle['read_date'] as String?;
      if (startStr != null) streakStart = DateTime.tryParse(startStr);
      if (endStr != null) streakEnd = DateTime.tryParse(endStr);
    }

    setState(() {
      _stats = CareerStats(
        totalBooks: totalBooks,
        totalDays: totalDays,
        authorCount: authorCount,
        avgRating: avgRating,
        firstReadDate: firstDate,
        longestStreak: longestStreak,
        streakStart: streakStart,
        streakEnd: streakEnd,
        avgCycleDays: avgCycle,
        yearlyComparison: yearlyComp
            .map((e) => YearlyComparison(
                  year: int.tryParse(e['year'] as String? ?? '0') ?? 0,
                  count: (e['count'] as int?) ?? 0,
                ))
            .toList(),
        topAuthors: topAuthors
            .map((e) => AuthorStat(
                  author: e['author'] as String,
                  count: (e['count'] as int?) ?? 0,
                ))
            .toList(),
      );
    });
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: '我的阅读生涯，坚持阅读遇见更好的自己！'),
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
          icon: const Text('←', style: TextStyle(fontSize: 20, color: Colors.white)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我的阅读生涯',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
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
                      // === Header ===
                      const Center(
                        child: Column(
                          children: [
                            Text(
                              '我的阅读生涯',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '坚持阅读，遇见更好的自己',
                              style: TextStyle(
                                fontSize: 14,
                                color: Color(0xB3FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // === Stats Grid（2x2）===
                      Row(
                        children: [
                          Expanded(
                              child: _LifeStatItem(
                                  icon: '📖',
                                  value: '${_stats!.totalBooks}',
                                  label: '累计读书（本）')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _LifeStatItem(
                                  icon: '📅',
                                  value: '${_stats!.totalDays}',
                                  label: '阅读天数')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                              child: _LifeStatItem(
                                  icon: '⭐',
                                  value:
                                      '${_stats!.authorCount}',
                                  label: '最爱作者（人数）')),
                          const SizedBox(width: 12),
                          Expanded(
                              child: _LifeStatItem(
                                  icon: '🏆',
                                  value: _stats!.avgRating
                                      ?.toStringAsFixed(1) ?? '-',
                                  label: '平均评分（书籍）')),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // === 开始阅读的第一天 ===
                      if (_stats!.firstReadDate != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '开始阅读的第一天',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0x99FFFFFF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_stats!.firstReadDate!.year} 年 ${_stats!.firstReadDate!.month} 月 ${_stats!.firstReadDate!.day} 日',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                                          // 计算已坚持天数（年/月/日）
                              Text(
                                '已坚持 ${_formatDuration(_stats!.firstReadDate!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0x80FFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // === 最长连续阅读 ===
                      Container(
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
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: Text('🔥', style: TextStyle(fontSize: 32)),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '最长连续阅读',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xCC1A1A2E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_stats!.longestStreak ?? 0} 天',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1A2E),
                                  ),
                                ),
                                if (_stats!.streakStart != null && _stats!.streakEnd != null)
                                  Text(
                                    '${_stats!.streakStart!.year} 年 ${_stats!.streakStart!.month} 月 - ${_stats!.streakEnd!.year} 年 ${_stats!.streakEnd!.month} 月',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xB31A1A2E),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // === 年度对比 ===
                      const Row(
                        children: [
                          Text('📈', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text(
                            '年度对比',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_stats!.yearlyComparison.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                '每年读书数量',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xCCFFFFFF),
                                ),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 140,
                                child: _YearChart(
                                    data: _stats!.yearlyComparison),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // === 最爱作者 TOP5 ===
                      const Row(
                        children: [
                          Text('✍️', style: TextStyle(fontSize: 18)),
                          SizedBox(width: 8),
                          Text(
                            '最爱作者 TOP5',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_stats!.topAuthors.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: _stats!.topAuthors
                                .asMap()
                                .entries
                                .map((entry) =>
                                    _AuthorRow(rank: entry.key + 1, author: entry.value))
                                .toList(),
                          ),
                        ),
                      const SizedBox(height: 24),

                      // === 分享按钮 ===
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _share,
                          icon: const Text('📤', style: TextStyle(fontSize: 16)),
                          label: const Text(
                            '分享我的阅读生涯',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: const Color(0xFFFFD700),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 4,
                            shadowColor: const Color(0xFFFFD700).withValues(alpha: 0.3),
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
}

String _formatDuration(DateTime start) {
  final now = DateTime.now();
  int years = now.year - start.year;
  int months = now.month - start.month;
  int days = now.day - start.day;
  if (days < 0) {
    months--;
    days += DateTime(now.year, now.month, 0).day;
  }
  if (months < 0) {
    years--;
    months += 12;
  }
  return '$years 年 $months 个月 $days 天';
}

/// 统计卡片（2x2 网格）
class _LifeStatItem extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _LifeStatItem({
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

/// 年度对比柱状图（设计稿样式）
class _YearChart extends StatelessWidget {
  final List<YearlyComparison> data;

  const _YearChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxVal = data.map((d) => d.count).reduce((a, b) => a > b ? a : b);
    final chartMax = maxVal > 0 ? maxVal.toDouble() : 1.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: data.map((yearData) {
        // 可用高度 = 容器140 - (数值标签18 + 年份标签18) = 104
        final barHeight = (yearData.count / chartMax) * 84.0;
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '${yearData.count}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: barHeight.clamp(4.0, 84.0),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFFFFD700), Color(0xFFFFC700)],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${yearData.year}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0x99FFFFFF),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

/// 作者排行行
class _AuthorRow extends StatelessWidget {
  final int rank;
  final AuthorStat author;

  const _AuthorRow({required this.rank, required this.author});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x1AFFFFFF)),
        ),
      ),
      child: Row(
        children: [
          // 排名徽章
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _rankGradient(rank),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: rank <= 3 ? const Color(0xFF1A1A2E) : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // 作者信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  author.author,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '读了 ${author.count} 本',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0x99FFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  LinearGradient _rankGradient(int rank) {
    switch (rank) {
      case 1:
        return const LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFC700)],
        );
      case 2:
        return const LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFFA8A8A8)],
        );
      case 3:
        return const LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFFB87333)],
        );
      default:
        return LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.3), Colors.white.withValues(alpha: 0.3)],
        );
    }
  }
}
