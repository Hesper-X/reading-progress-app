import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/checkin.dart';
import '../models/book.dart';
import '../providers/checkin_provider.dart';
import '../providers/books_provider.dart';
import '../repositories/checkin_repository.dart';
import '../repositories/book_repository.dart';
import '../databases/database_helper.dart';
import '../theme/colors.dart';
import '../routes/app_routes.dart';
import '../widgets/book_cover.dart';

/// 书籍笔记时间轴页（V3.5 新增）
class BookNotesPage extends StatefulWidget {
  final int bookId;

  const BookNotesPage({super.key, required this.bookId});

  @override
  State<BookNotesPage> createState() => _BookNotesPageState();
}

class _BookNotesPageState extends State<BookNotesPage> {
  Book? _book;
  List<CheckinDetail> _checkins = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final bookRepo = BookRepository(dbHelper);
      final checkinRepo = CheckinRepository(dbHelper);

      final book = await bookRepo.getById(widget.bookId);
      final checkins = await checkinRepo.getBookCheckins(widget.bookId);

      if (mounted) {
        setState(() {
          _book = book;
          _checkins = checkins;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteCheckins() async {
    if (_book == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除《${_book!.title}》的所有阅读记录？'),
        content: const Text('此操作不可撤销。（不影响书籍数据）'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定删除', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final dbHelper = DatabaseHelper.instance;
      final checkinRepo = CheckinRepository(dbHelper);
      await checkinRepo.deleteBookCheckins(widget.bookId);

      // 刷新
      if (mounted) {
        context.read<CheckinProvider>().refreshCurrentMonth();
        setState(() => _checkins = []);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('阅读记录已删除')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 18, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('阅读笔记',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _deleteCheckins,
            child: const Text('删除本书数据',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _book == null
              ? const Center(child: Text('书籍不存在'))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final book = _book!;
    final hasCheckin = _checkins.isNotEmpty;
    // 计算阅读累计
    int totalMinutes = _checkins.fold(0, (sum, c) => sum + (c.durationMin ?? 0));
    int checkinDays = _checkins.map((c) => c.checkinDate).toSet().length;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部摘要
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDEE2E6), width: 1),
            ),
            child: Row(
              children: [
                BookCover(coverPath: book.coverPath, width: 44, height: 56, borderRadius: 6, reading: true),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      Row(
                        children: [
                          Expanded(
                            child: Text(book.author.isNotEmpty ? book.author : '',
                                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (book.readingCycleDays != null)
                            Text('阅读周期 ${book.readingCycleDays} 天',
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        ],
                      ),
                      if (hasCheckin) ...[
                        const SizedBox(height: 4),
                        Text('阅读累计 ${_formatDuration(totalMinutes)} · 打卡 $checkinDays 天',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 空态
          if (!hasCheckin)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 60),
                child: Column(
                  children: [
                    Icon(Icons.menu_book, size: 64, color: AppColors.border),
                    SizedBox(height: 16),
                    Text('还没有阅读记录', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                    SizedBox(height: 8),
                    Text('开始打卡吧', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),

          // 时间轴
          if (hasCheckin) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text('📝', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 4),
                  Text('阅读笔记',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ..._buildTimeline(context),
          ],

          // 新增打卡按钮
          if (hasCheckin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SizedBox(
                width: double.infinity,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('新增打卡',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(BuildContext context) {
    // 按日期分组
    final grouped = <String, List<CheckinDetail>>{};
    for (final c in _checkins) {
      grouped.putIfAbsent(c.checkinDate, () => []).add(c);
    }

    // 日期列表倒序
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final widgets = <Widget>[];
    for (int i = 0; i < dates.length; i++) {
      final date = dates[i];
      final details = grouped[date]!;
      final hasNote = details.any((d) => d.note != null && d.note!.isNotEmpty);

      // 日期行
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧圆点 + 连线
              Column(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: hasNote ? AppColors.primary : const Color(0xFFADB5BD),
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (i < dates.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: const Color(0xFFE9ECEF),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              // 日期内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatDate(date)} ${_getWeekday(date)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...details.map((d) => _buildRecordCard(d)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildRecordCard(CheckinDetail detail) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.durationMin != null && detail.durationMin! > 0)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '⏱ ${detail.formattedDuration}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          Text(
            detail.note != null && detail.note!.isNotEmpty
                ? detail.note!
                : '(当日无笔记)',
            style: TextStyle(
              fontSize: 13,
              color: detail.note != null && detail.note!.isNotEmpty
                  ? const Color(0xFF495057)
                  : const Color(0xFFADB5BD),
              fontStyle: detail.note != null && detail.note!.isNotEmpty
                  ? FontStyle.normal
                  : FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int minutes) {
    if (minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0 && m == 0) return '';
    if (h == 0) return '$m 分钟';
    if (m == 0) return '$h 小时';
    return '${h}小时${m}分钟';
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${int.parse(parts[0])}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  String _getWeekday(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return '';
    final date = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    const days = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return days[date.weekday - 1];
  }
}
