import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/checkin_provider.dart';
import '../providers/books_provider.dart';
import '../models/checkin.dart';
import '../theme/colors.dart';
import 'checkin_dialog.dart';
import 'checkin_option_sheet.dart';

/// 打卡日历组件（V3.5）
/// 月视图 + 连续天数 + 点击日期弹出 Dialog
class CheckinCalendar extends StatefulWidget {
  const CheckinCalendar({super.key});

  @override
  State<CheckinCalendar> createState() => _CheckinCalendarState();
}

class _CheckinCalendarState extends State<CheckinCalendar> {
  // ============ 日期状态计算 ============

  /// 生成当月日期网格数据
  /// 返回 List<List<int?>>，外层周、内层天数，null = 跨月占位
  List<List<int?>> _buildDateGrid(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final totalDays = lastDay.day;
    // 1=周一 ... 7=周日
    final startWeekday = firstDay.weekday;

    final grid = <List<int?>>[];
    List<int?> week = [];

    // 填充月初空白（1号之前）
    for (int i = 1; i < startWeekday; i++) {
      week.add(null);
    }

    for (int day = 1; day <= totalDays; day++) {
      week.add(day);
      if (week.length == 7) {
        grid.add(week);
        week = [];
      }
    }

    // 填充月末空白
    if (week.isNotEmpty) {
      while (week.length < 7) {
        week.add(null);
      }
      grid.add(week);
    }

    return grid;
  }

  // ============ Dialog 触发 ============

  void _onDateTap(int day) {
    final now = DateTime.now();
    final provider = context.read<CheckinProvider>();
    final year = provider.currentYear;
    final month = provider.currentMonth;
    final today = DateTime(now.year, now.month, now.day);
    final tappedDate = DateTime(year, month, day);

    // 未来日期不可点击
    if (tappedDate.isAfter(today)) return;

    final dateStr =
        '${year}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
    final isToday = tappedDate == today;
    final isCheckedIn = provider.checkinDates.contains(dateStr);

    if (isToday) {
      if (isCheckedIn) {
        // 今日已打卡 → 选择浮层
        _showOptionSheet(provider, dateStr);
      } else {
        // 今日未打卡 → 新建打卡 Dialog
        _showNewDialog(provider, dateStr);
      }
    } else if (isCheckedIn) {
      // 过往已打卡 → 详情 Dialog
      _showDetailDialog(provider, dateStr);
    }
    // 过往未打卡 → 无交互
  }

  // ============ Dialog 方法 ============

  void _showNewDialog(CheckinProvider provider, String dateStr, {int? initialBookId}) {
    final booksProvider = context.read<BooksProvider>();
    final readingBooks = booksProvider.readingBooks;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckinNewDialog(
        dateStr: dateStr,
        readingBooks: readingBooks,
        initialBookId: initialBookId,
        onSubmit: (bookId, durationMin, note) async {
          final error = await provider.addCheckin(
            bookId: bookId,
            durationMin: durationMin,
            note: note,
          );
          if (error == null) {
            _showToast('打卡成功 ☀️');
          } else {
            _showToast(error);
          }
        },
      ),
    );
  }

  void _showOptionSheet(CheckinProvider provider, String dateStr) {
    final lastCheckin = provider.lastCheckin;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => CheckinOptionSheet(
        dateStr: dateStr,
        onNewCheckin: () {
          Navigator.pop(context); // close option sheet
          _showNewDialog(provider, dateStr,
              initialBookId: lastCheckin?.bookId);
        },
        onViewDetail: () {
          Navigator.pop(context); // close option sheet
          _showDetailDialog(provider, dateStr);
        },
      ),
    );
  }

  void _showDetailDialog(CheckinProvider provider, String dateStr) {
    // 预创建 Future，避免 builder 重复调用时重建导致闪烁
    final future = provider.getDaySummary(dateStr);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FutureBuilder<CheckinDaySummary>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('暂无数据'));
          }
          return CheckinDetailDialog(summary: snapshot.data!);
        },
      ),
    );
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============ Build ============

  @override
  Widget build(BuildContext context) {
    return Consumer<CheckinProvider>(
      builder: (context, provider, _) {
        final year = provider.currentYear;
        final month = provider.currentMonth;
        final grid = _buildDateGrid(year, month);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final streakDays = provider.streakDays;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：标题 + 连续天数 + 月份切换
              Row(
                children: [
                  const Text('📅', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  const Text(
                    '阅读打卡',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (streakDays > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '🔥 连续 $streakDays 天',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => provider.goToPrevMonth(),
                        child: const Text(
                          '‹',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        provider.monthLabel,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => provider.goToNextMonth(),
                        child: const Text(
                          '›',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // 星期行
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['日', '一', '二', '三', '四', '五', '六']
                    .map(
                      (d) => SizedBox(
                        width: 34,
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 4),
              // 日期网格
              ...grid.map((week) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: week.map((day) {
                      if (day == null) {
                        return const SizedBox(
                          width: 34,
                          height: 34,
                        );
                      }

                      final date = DateTime(year, month, day);
                      final dateStr =
                          '$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';
                      final isToday = date == today;
                      final isCheckedIn =
                          provider.checkinDates.contains(dateStr);
                      final isFuture = date.isAfter(today);

                      Color bgColor = Colors.transparent;
                      Color textColor = AppColors.textPrimary;
                      Color borderColor = Colors.transparent;
                      FontWeight fontWeight = FontWeight.w500;
                      bool isClickable = true;

                      if (isFuture) {
                        textColor = AppColors.textMuted;
                        isClickable = false;
                      } else if (isCheckedIn) {
                        bgColor = AppColors.primary;
                        textColor = Colors.white;
                        fontWeight = FontWeight.w600;
                      }

                      if (isToday) {
                        borderColor = AppColors.primary;
                      }

                      return GestureDetector(
                        onTap:
                            isClickable ? () => _onDateTap(day) : null,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: bgColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: borderColor,
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: fontWeight,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
