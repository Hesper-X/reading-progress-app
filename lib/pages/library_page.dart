import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../providers/purchase_provider.dart';
import '../theme/colors.dart';
import '../routes/app_routes.dart';
import '../widgets/book_cover.dart';

/// 书架页（V3.0：三Tab：想读/在读/已读）
class LibraryPage extends StatefulWidget {
  final String? initialTab; // 'wish' | 'reading' | 'done'
  const LibraryPage({super.key, this.initialTab});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _doneCount = 0;

  // Tab 索引映射
  static const _tabIndex = {'wish': 0, 'reading': 1, 'done': 2};

  @override
  void initState() {
    super.initState();
    final initialIndex = _tabIndex[widget.initialTab] ?? 0;
    _tabController = TabController(length: 3, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  /// V3.4: 计算总书籍数（想读+在读+已读）
  int _totalBookCount(BooksProvider provider) {
    return provider.wishBooks.length +
        provider.readingBooks.length +
        _doneCount;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
        title: const Text('我的书架',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ),
      body: Consumer<BooksProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Tab 栏（三Tab + V3.4 容量角标）
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: AppColors.tabInactive,
                        indicatorColor: AppColors.primary,
                        indicatorWeight: 3,
                        indicatorSize: TabBarIndicatorSize.tab,
                        tabs: [
                          Tab(text: '想读 ${provider.wishBooks.isNotEmpty ? '(${provider.wishBooks.length})' : ''}'),
                          Tab(text: '在读 ${provider.readingBooks.isNotEmpty ? '(${provider.readingBooks.length})' : ''}'),
                          Tab(text: '已读 ${_doneCount > 0 ? '($_doneCount)' : ''}'),
                        ],
                      ),
                    ),
                    // V3.4: 容量角标
                    _CapacityBadge(totalBooks: _totalBookCount(provider)),
                  ],
                ),
              ),
              Expanded(
                child: IndexedStack(
                  index: _tabController.index,
                  children: [
                    _WishTab(books: provider.wishBooks),
                    _ReadingTab(books: provider.readingBooks),
                    _DoneTab(books: provider.doneBooks, onCountChanged: (count) {
                      if (count != _doneCount) {
                        setState(() => _doneCount = count);
                      }
                    }),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============ 想读 Tab ============

class _WishTab extends StatelessWidget {
  final List<Book> books;
  const _WishTab({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return _emptyState(context, '还没有想读的书', '点击首页 [+读书清单] 添加想读的书');
    }
    final sorted = List<Book>.from(books)
      ..sort((a, b) => (b.createdAt ?? DateTime(2000)).compareTo(a.createdAt ?? DateTime(2000)));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _WishBookCard(book: sorted[i]),
    );
  }
}

class _WishBookCard extends StatelessWidget {
  final Book book;
  const _WishBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    // 取创建日期（用于显示加入想读日期）
    final addedDate = book.createdAt ?? DateTime.now();
    final dateStr = '${addedDate.year}年${addedDate.month}月${addedDate.day}日';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9ECEF), width: 1),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧：标题+作者
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (book.author.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(book.author, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ),
              ],
            ),
          ),
          // 右侧：开始阅读按钮 + 删除 + 日期
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () async {
                      // 跳转到「开始阅读」页面，让用户确认/补充封面、日期等
                      final result = await Navigator.pushNamed(
                        context,
                        AppRoutes.add,
                        arguments: {
                          'title': book.title,
                          'author': book.author,
                        },
                      );
                      // 如果用户确实添加了在读（有结果返回），则删除想读记录
                      if (result == true && book.id != null) {
                        await context.read<BooksProvider>().deleteBook(book.id!);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.primary, width: 1),
                        color: Colors.white,
                      ),
                      child: const Text('开始阅读',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.primary)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // V3.2 编辑（点击跳转到 /add 路由并传入 Book 对象作为 editData）
                  GestureDetector(
                    onTap: () async {
                      await Navigator.pushNamed(context, AppRoutes.wish, arguments: book);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFC9C9), width: 1),
                        color: const Color(0xFFFFF5F5),
                      ),
                      child: const Text('编辑',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFFFF6B6B))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateStr,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============ 在读 Tab ============

class _ReadingTab extends StatelessWidget {
  final List<Book> books;
  const _ReadingTab({required this.books});

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return _emptyState(context, '还没有在读书籍', '在[首页]或者[书架]的[想读]清单，点击[开始阅读]后，\n它们会出现在这里');
    }
    final sorted = List<Book>.from(books)
      ..sort((a, b) => (b.startDate).compareTo(a.startDate));
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ReadingBookCard(book: sorted[i]),
    );
  }
}

class _ReadingBookCard extends StatelessWidget {
  final Book book;
  const _ReadingBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFFFF5F5), Color(0xFFFFE3E3)]),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 左侧：封面图片（有真实封面时显示，否则 emoji 占位）
          BookCover(
            coverPath: book.coverPath,
            width: 44,
            height: 56,
            borderRadius: 6,
            reading: true,
          ),
          const SizedBox(width: 12),
          // 中间：书名 + 作者
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (book.author.isNotEmpty)
                  Text(book.author, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // 右侧：胶囊按钮 + 已读天数
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标记读完（红色边框胶囊，符合设计稿 action-capsule--primary）
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.finish, arguments: book),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFF6B6B), width: 1),
                        color: Colors.white,
                      ),
                      child: const Text('标记已读',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFFF6B6B))),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // V3.2 编辑（点击跳转到 /add 路由并传入 Book 对象作为 editData）
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, AppRoutes.add, arguments: book),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFC9C9), width: 1),
                        color: const Color(0xFFFFF5F5),
                      ),
                      child: const Text('编辑',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFFF6B6B))),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('已读 ${book.elapsedDays} 天',
                  style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  void _abandonBook(BuildContext context, Book book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('放弃阅读《${book.title}》？'),
        content: const Text('该书籍将从在读书架移除，不计入统计数据。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('继续阅读', style: TextStyle(color: AppColors.primary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定放弃', style: TextStyle(color: AppColors.textMuted))),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<BooksProvider>().abandonBook(book.id!);
    }
  }
}

// ============ 已读 Tab（V3.0：感想框重构 + 淡绿边框） ============

class _DoneTab extends StatefulWidget {
  final List<Book> books;
  final ValueChanged<int>? onCountChanged;
  const _DoneTab({required this.books, this.onCountChanged});

  @override
  State<_DoneTab> createState() => _DoneTabState();
}

class _DoneTabState extends State<_DoneTab> {
  int? _selectedYear;
  List<int> _availableYears = [];
  int _sortMode = 0; // 0=读完日期, 1=评分, 2=书名
  bool _sortAsc0 = false;
  bool _sortAsc1 = false;
  bool _sortAsc2 = false;

  @override
  void initState() {
    super.initState();
    _availableYears = _deriveYears();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onCountChanged?.call(_filteredBooks.length);
    });
  }

  @override
  void didUpdateWidget(_DoneTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.books != widget.books) {
      setState(() {
        _availableYears = _deriveYears();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onCountChanged?.call(_filteredBooks.length);
      });
    }
  }

  List<int> _deriveYears() {
    final currentYear = DateTime.now().year;
    final yearsSet = widget.books
        .where((b) => b.readDate != null)
        .map((b) => b.readDate!.year)
        .toSet();
    yearsSet.add(currentYear);
    final years = yearsSet.toList();
    years.sort((a, b) => b.compareTo(a));
    return years;
  }

  List<Book> get _filteredBooks {
    List<Book> result = List.from(widget.books);
    if (_selectedYear != null) {
      result = result.where((b) => b.readDate?.year == _selectedYear).toList();
    }
    if (_sortMode == 0) {
      result.sort((a, b) => _sortAsc0
          ? (a.readDate ?? DateTime(2000)).compareTo(b.readDate ?? DateTime(2000))
          : (b.readDate ?? DateTime(2000)).compareTo(a.readDate ?? DateTime(2000)));
    } else if (_sortMode == 1) {
      result.sort((a, b) => _sortAsc1
          ? (a.rating ?? 0).compareTo(b.rating ?? 0)
          : (b.rating ?? 0).compareTo(a.rating ?? 0));
    } else if (_sortMode == 2) {
      result.sort((a, b) => _sortAsc2 ? b.title.compareTo(a.title) : a.title.compareTo(b.title));
    }
    return result;
  }

  bool get _hasFilter => _selectedYear != null;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBooks;
    return Column(children: [
      // ══ V3.3 新增：已读添加横条 ══
      GestureDetector(
        onTap: () => Navigator.pushNamed(context, AppRoutes.addDone),
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFDEE2E6), width: 2),
            borderRadius: BorderRadius.circular(14),
            color: const Color(0xFFFAFAFA),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('+',
                  style: TextStyle(
                      fontSize: 18,
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w300)),
              const SizedBox(width: 6),
              const Text('标记已读',
                  style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFFFF6B6B),
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),

      // 筛选/排序栏 — 按设计稿：整体靠左，上排年份下排排序
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 年份 Chips — V3.3：横向滚动（overflow-x: auto + 隐藏滚动条）
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _YearChip(label: '全部', isActive: !_hasFilter,
                      onTap: () => setState(() {_selectedYear = null; widget.onCountChanged?.call(_filteredBooks.length);})),
                  const SizedBox(width: 6),
                  ..._availableYears.map((y) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _YearChip(
                        label: '$y', isActive: _selectedYear == y,
                        onTap: () => setState(() {_selectedYear = _selectedYear == y ? null : y; widget.onCountChanged?.call(_filteredBooks.length);})),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // 排序按钮组
            Row(
              children: [
                _SortButton(
                  label: '日期 新→旧', another: '日期 旧→新',
                  isActive: _sortMode == 0, isAsc: _sortAsc0,
                  onTap: () => setState(() { if (_sortMode == 0) { _sortAsc0 = !_sortAsc0; } else { _sortMode = 0; _sortAsc0 = false; }}),
                ),
                const SizedBox(width: 6),
                _SortButton(
                  label: '评分 高→低', another: '评分 低→高',
                  isActive: _sortMode == 1, isAsc: _sortAsc1,
                  onTap: () => setState(() { if (_sortMode == 1) { _sortAsc1 = !_sortAsc1; } else { _sortMode = 1; _sortAsc1 = false; }}),
                ),
                const SizedBox(width: 6),
                _SortButton(
                  label: '书名 A→Z', another: '书名 Z→A',
                  isActive: _sortMode == 2, isAsc: _sortAsc2,
                  onTap: () => setState(() { if (_sortMode == 2) { _sortAsc2 = !_sortAsc2; } else { _sortMode = 2; _sortAsc2 = false; }}),
                ),
              ],
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: Color(0xFFF1F3F5)),
      // 列表
      Expanded(
        child: filtered.isEmpty
            ? _emptyState(context, _hasFilter ? '没有找到匹配的书籍' : '还没有读完的书籍', '在[在读]清单或者[已读]页，点击[标记已读]，\n它们会出现在这里')
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _DoneBookCard(book: filtered[i]),
              ),
      ),
    ]);
  }
}

/// 已读书籍卡片（V3.0：淡绿边框 + 感想框重构 + 封面组件）
class _DoneBookCard extends StatelessWidget {
  final Book book;
  const _DoneBookCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final hasNotes = book.notes != null && book.notes!.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // V3.0：已读卡片淡绿边框 #B7EBD5
        border: Border.all(color: const Color(0xFFB7EBD5), width: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 上部分：封面+书名+评分+日期
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            BookCover(coverPath: book.coverPath, width: 68, height: 88, reading: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(book.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    // V3.3 编辑按钮 → 路由到 07_3 添加已读书籍（编辑模式）
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, AppRoutes.addDone, arguments: book),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFC9C9), width: 1),
                          color: const Color(0xFFFFF5F5),
                        ),
                        child: const Text('编辑',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFFF6B6B))),
                      ),
                    ),
                  ],
                ),
                if (book.author.isNotEmpty)
                  Text(book.author, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (book.rating != null)
                      Row(children: List.generate(5, (i) => Icon(
                          i < book.rating!.round() ? Icons.star : Icons.star_border,
                          size: 16, color: i < book.rating!.round() ? AppColors.starActive : AppColors.border))),
                    if (book.formattedReadDate != null)
                      Text(book.formattedReadDate!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                if (book.readingCycleDays != null)
                  Padding(padding: const EdgeInsets.only(top: 2),
                      child: Text('阅读了 ${book.readingCycleDays} 天', style: const TextStyle(fontSize: 12, color: AppColors.textMuted))),
                if (book.readCount > 1)
                  Padding(padding: const EdgeInsets.only(top: 2),
                      child: Text('已读 ${book.readCount} 次', style: const TextStyle(fontSize: 12, color: AppColors.primary))),
              ]),
            ),
          ]),
          // 下部分：感想框（V3.0：通栏底部行）
          if (hasNotes) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
                border: const Border(left: BorderSide(color: AppColors.primary, width: 3)),
              ),
              child: Text(
                book.notes!,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            // 无感想时：一行 flex 居中
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: const Center(
                child: Text('暂无感想', style: TextStyle(fontSize: 13, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============ 通用组件 ============

/// 空状态提示
Widget _emptyState(BuildContext context, String title, String subtitle, {bool showAddButton = false}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.menu_book, size: 64, color: AppColors.border),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ],
        if (showAddButton) ...[          
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, AppRoutes.wish),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
              child: const Text('去添加', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ],
      ]),
    ),
  );
}

class _YearChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _YearChip({required this.label, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFFFF5F5) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive ? const Color(0xFFFF6B6B) : const Color(0xFFDEE2E6),
              width: 1,
            ),
          ),
          child: Center(child: Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                  color: isActive ? const Color(0xFFFF6B6B) : const Color(0xFF868E96)))),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final String another;
  final bool isActive;
  final bool isAsc;
  final VoidCallback onTap;
  const _SortButton({required this.label, required this.another, required this.isActive, required this.isAsc, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayText = isAsc ? another : label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFF5F5) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? const Color(0xFFFF6B6B) : const Color(0xFFDEE2E6),
            width: 1,
          ),
        ),
        child: Center(child: Text(displayText, style: TextStyle(fontSize: 12,
            color: isActive ? AppColors.primary : const Color(0xFF495057),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400))),
      ),
    );
  }
}

// ============ V3.4 容量角标组件 ============

/// 书架页容量角标：显示当前书籍数/5，点击弹出升级引导
class _CapacityBadge extends StatelessWidget {
  final int totalBooks;
  const _CapacityBadge({required this.totalBooks});

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<PurchaseProvider>().isPro;
    // Pro 用户不渲染
    if (isPro) return const SizedBox.shrink();

    final isFull = totalBooks >= 5;
    final displayCount = totalBooks > 5 ? 5 : totalBooks;

    return GestureDetector(
      onTap: () => _showCapacityToast(context),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isFull ? const Color(0xFFFFF0F0) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$displayCount/5',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isFull ? const Color(0xFFE34D59) : const Color(0xFF868E96),
            ),
          ),
        ),
      ),
    );
  }

  void _showCapacityToast(BuildContext context) {
    OverlayEntry? overlayEntry;
    Timer? autoDismissTimer;

    overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () {
          overlayEntry?.remove();
          autoDismissTimer?.cancel();
        },
        child: Stack(
          children: [
            // 透明遮罩，点击外部关闭
            Container(color: Colors.transparent),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 100,
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF212529),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '基础版最多保存 5 本书，升级 Pro 版无限添加',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () {
                            overlayEntry?.remove();
                            autoDismissTimer?.cancel();
                            Navigator.pushNamed(context, AppRoutes.pro);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '去升级 Pro',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);
    autoDismissTimer = Timer(const Duration(seconds: 3), () {
      overlayEntry?.remove();
    });
  }
}

class _ActionLink extends StatelessWidget {
  final String text;
  final Color color;
  final VoidCallback onTap;
  const _ActionLink({required this.text, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(onTap: onTap,
        child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)));
  }
}
