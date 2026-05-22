import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import '../models/book.dart';
import '../models/filter_state.dart';
import '../providers/books_provider.dart';
import '../providers/filter_provider.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';

/// 分享页（V3.0：可开关模块 + 弹窗预览 + 筛选联动 + 精简模式）
class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final _previewKey = GlobalKey();
  bool _isKeyboardVisible = false;

  // 统计模块开关（默认全部开启）
  bool _showFavoriteBooks = true;
  bool _showLongestShortest = true;
  bool _showReadList = true;
  bool _showFavoriteAuthors = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final currentKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    if (_isKeyboardVisible && !currentKeyboardVisible) {
      _focusNode.unfocus();
    }
    _isKeyboardVisible = currentKeyboardVisible;
  }

  Future<void> _generateAndShare() async {
    _focusNode.unfocus();

    // 显示生成中
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('生成中…'), duration: Duration(milliseconds: 500)),
    );
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final boundary =
          _previewKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      // 保存临时文件
      final tempDir = Directory.systemTemp.path;
      final file = File('$tempDir/share.png');
      await file.writeAsBytes(byteData.buffer.asUint8List());

      if (!mounted) return;

      // 弹窗预览
      _showShareModal(image, file);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('生成失败，请重试')),
        );
      }
    }
  }

  void _showShareModal(ui.Image image, File file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ShareModal(
        image: image,
        file: file,
        onShare: () async {
          Navigator.pop(ctx);
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path)],
              text: _textController.text.isNotEmpty
                  ? _textController.text
                  : AppConstants.slogan,
            ),
          );
        },
        onSave: () async {
          Navigator.pop(ctx);
          try {
            final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
            if (bytes != null) {
              await ImageGallerySaverPlus.saveImage(
                bytes.buffer.asUint8List(),
                name: '读书进度_${DateTime.now().millisecondsSinceEpoch}',
                isReturnImagePathOfIOS: false,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ 已保存到相册'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('保存失败: $e')),
              );
            }
          }
        },
        onEdit: () => Navigator.pop(ctx),
      ),
    );
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
        title: const Text(
          '分享我的读书进度',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
      ),
      body: Consumer2<BooksProvider, FilterProvider>(
        builder: (context, booksProvider, filterProvider, _) {
          final filterState = filterProvider.state;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
                children: [
                  // === V3.1 数据范围提示横幅（仅「我的阅读生涯」路径显示） ===
                  if (filterState.fromReadingLife)
                    _DataScopeBanner(booksProvider: booksProvider),
                  const SizedBox(height: 16),
                  // === 预览卡片（粉色框外可见，仅红色渐变图内部可截图） ===
                  _SharePreviewCard(
                    previewKey: _previewKey,
                    customText: _textController.text.isNotEmpty
                        ? _textController.text
                        : null,
                    filterState: filterState,
                    showFavoriteBooks: _showFavoriteBooks,
                    showLongestShortest: _showLongestShortest,
                    showReadList: _showReadList,
                    showFavoriteAuthors: _showFavoriteAuthors,
                  ),
                  const SizedBox(height: 16),
                  // === 进度环规则提示（黄色气泡） ===
                  if (!filterState.showProgressRing)
                    _ProgressRingRuleTip(),
                  const SizedBox(height: 16),
                  // === 自定义文案 ===
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('自定义文案', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ),
                  const SizedBox(height: 8),
                  _CharInputField(
                    controller: _textController,
                    focusNode: _focusNode,
                    hintText: '今年读的书，配得上你的野心吗？',
                    maxLength: 200,
                  ),
                  const SizedBox(height: 20),
                  // === 统计模块开关 ===
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '分享页展示控制',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _ModuleSwitches(
                    showFavoriteBooks: _showFavoriteBooks,
                    showLongestShortest: _showLongestShortest,
                    showReadList: _showReadList,
                    showFavoriteAuthors: _showFavoriteAuthors,
                    onToggle: (key, value) {
                      setState(() {
                        switch (key) {
                          case 'favoriteBooks': _showFavoriteBooks = value; break;
                          case 'longestShortest': _showLongestShortest = value; break;
                          case 'readList': _showReadList = value; break;
                          case 'favoriteAuthors': _showFavoriteAuthors = value; break;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  // === 生成分享图按钮 ===
                  SizedBox(
                    width: double.infinity,
                    child: GestureDetector(
                      onTap: _generateAndShare,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Text('生成分享图',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
          );
        },
      ),
    );
  }
}

// ============ 分享预览卡片 ============

class _SharePreviewCard extends StatefulWidget {
  final GlobalKey previewKey;
  final String? customText;
  final FilterState filterState;
  final bool showFavoriteBooks;
  final bool showLongestShortest;
  final bool showReadList;
  final bool showFavoriteAuthors;

  const _SharePreviewCard({
    required this.previewKey,
    required this.customText,
    required this.filterState,
    required this.showFavoriteBooks,
    required this.showLongestShortest,
    required this.showReadList,
    required this.showFavoriteAuthors,
  });

  @override
  State<_SharePreviewCard> createState() => _SharePreviewCardState();
}

class _SharePreviewCardState extends State<_SharePreviewCard> {
  bool get _isCurrentYear => (widget.filterState.selectedYear ?? DateTime.now().year) == DateTime.now().year;
  bool get _showRing => !widget.filterState.fromReadingLife && _isCurrentYear && widget.filterState.selectedMonth == null;

  @override
  Widget build(BuildContext context) {
    final filter = widget.filterState;
    final year = filter.selectedYear ?? DateTime.now().year;
    final month = filter.selectedMonth;

    // 从 BooksProvider 获取数据
    final booksProvider = context.watch<BooksProvider>();
    final doneBooks = booksProvider.doneBooks;

    // 阅读生涯预览：使用全部已读书籍
    // 否则按年份/月份筛选
    late List<Book> scopeList;
    late int readCount;
    late int totalCount;
    late double progress;
    late bool isCelebration;

    if (filter.fromReadingLife) {
      scopeList = doneBooks;
      readCount = scopeList.length;
      totalCount = 0;
      progress = 0.0;
      isCelebration = false;
    } else {
      Iterable<Book> scopeBooks;
      if (month == null) {
        scopeBooks = doneBooks.where((b) => b.readDate?.year == year);
      } else {
        scopeBooks = doneBooks.where(
            (b) => b.readDate?.year == year && b.readDate?.month == month);
      }
      scopeList = scopeBooks.toList();
      readCount = scopeList.length;
      totalCount = booksProvider.yearlyGoal;
      progress = totalCount > 0 ? (readCount / totalCount).clamp(0.0, 1.0) : 0.0;
      isCelebration = _isCurrentYear && month == null && readCount >= totalCount && totalCount > 0;
    }

    // 计算最爱书籍 Top3
    final favBooks = _computeFavoriteBooks(scopeList);
    // 最长最短
    final longest = _computeLongest(scopeList);
    final shortest = _computeShortest(scopeList);
    // 已读书单
    final readList = scopeList.toList()
      ..sort((a, b) => (b.readDate ?? DateTime(2000)).compareTo(a.readDate ?? DateTime(2000)));
    // 最爱作者
    final favAuthors = _computeFavoriteAuthors(scopeList);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE3E3), Colors.white],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDEE2E6), width: 2),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // === 预览大标题 ===
          const Center(child: Text('分享预览', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF212529)))),
          const SizedBox(height: 24),
          // 分享卡片主体（红色渐变）—— 此区域用于截图生成
          RepaintBoundary(
            key: widget.previewKey,
            child: Container(
            width: double.infinity,
            // 庆祝模式时顶部内边距缩小，让装饰更贴近上边界
            padding: EdgeInsets.fromLTRB(24, isCelebration ? 12 : 24, 24, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
              ),
            ),
            child: Stack(
              children: [
                // 金色微光背景（V3.1庆祝模式 — 极淡渐变）
                if (isCelebration)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x0FFFD700), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                // 内容
                Column(
                  children: [
                    // === 标题行：庆祝模式时装饰绝对定位，标题正常流 ===
                    Stack(
                      children: [
                        // 标题正常流
                        Padding(
                          padding: EdgeInsets.only(top: isCelebration ? 36 : 0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book, size: 18, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('${filter.selectedYear ?? DateTime.now().year} 读书进度条',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                        // 庆祝装饰：绝对定位，不占流（与设计稿一致）
                        if (isCelebration) ...[Positioned(
                          top: 2, left: 2,
                          child: const Text('🎉🎊', style: TextStyle(fontSize: 16, letterSpacing: 1)),
                        ), Positioned(
                          top: 2, right: 2,
                          child: const Text('⭐⭐⭐⭐⭐', style: TextStyle(fontSize: 14, letterSpacing: 2)),
                        )],
                      ],
                    ),
                const SizedBox(height: 20),
                // === 进度环 或 精简模式 ===
                if (_showRing) ...[
                  // 标准模式：进度环
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _ShareRingPainter(progress: progress),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('已读完 $readCount / $totalCount本',
                          style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.9))),
                      if (isCelebration) const SizedBox(height: 6),
                      if (isCelebration)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF51CF66),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('🏆 ', style: TextStyle(fontSize: 11)),
                                  Text('目标达成！',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ] else ...[
                  // 精简模式：大数字替代
                  Text(
                    '$readCount',
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w700, color: Colors.white, height: 1.0),
                  ),
                  const SizedBox(height: 8),
                  Text('本书已读完', style: const TextStyle(fontSize: 16, color: Colors.white70)),
                ],

                // === 用户自定义文案（在已读数和统计模块之间，无输入时显示hint示例） ===
                const SizedBox(height: 8),
                Text(
                  widget.customText ?? '今年读的书，配得上你的野心吗？',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: widget.customText != null
                        ? const Color(0xB3FFFFFF)
                        : const Color(0x55FFFFFF),
                  ),
                ),

                // === 统计模块（分割线+容器，同高保真） ===
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Colors.white30, width: 1)),
                  ),
                  padding: const EdgeInsets.only(top: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (widget.showFavoriteBooks && favBooks.isNotEmpty)
                  _ShareFavBooks(data: favBooks),
                if (widget.showLongestShortest && longest != null)
                  _ShareDurSection(longest: longest!, shortest: shortest ?? longest!),
                if (widget.showReadList && readList.isNotEmpty)
                  _ShareReadList(books: readList.take(5).toList()),
                if (widget.showFavoriteAuthors && favAuthors.isNotEmpty)
                  _ShareFavAuthors(data: favAuthors),
                  ]),
                ),

                // === 品牌水印（无分割线） ===
                const SizedBox(height: 6),
                const Text('来自读书进度条 App',
                    style: TextStyle(fontSize: 12, color: Color(0xB3FFFFFF))),
                const SizedBox(height: 4),
                const Text(
                  '把你读完的书，变成一种生命的进度',
                  style: TextStyle(fontSize: 11, color: Color(0x8CFFFFFF)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
        ],
      ),
    );
  }

  // _buildModule 已替换为下方独立组件

  List<Map<String, dynamic>> _computeFavoriteBooks(List<Book> books) {
    final grouped = <String, List<Book>>{};
    for (final b in books) {
      grouped.putIfAbsent(b.title, () => []).add(b);
    }
    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.length.compareTo(a.value.length);
        if (cmp != 0) return cmp;
        final aRating = a.value.fold<int>(0, (s, e) => s + (e.rating?.toInt() ?? 0));
        final bRating = b.value.fold<int>(0, (s, e) => s + (e.rating?.toInt() ?? 0));
        return bRating.compareTo(aRating);
      });
    return entries.take(3).map((e) => {
      'title': e.key,
      'author': e.value.first.author,
      'read_count': e.value.length,
    }).toList();
  }

  Map<String, dynamic>? _computeLongest(List<Book> books) {
    if (books.isEmpty) return null;
    final withDays = books.where((b) => b.readingCycleDays != null && b.readingCycleDays! > 0).toList();
    if (withDays.isEmpty) return null;
    withDays.sort((a, b) => b.readingCycleDays!.compareTo(a.readingCycleDays!));
    return {'title': withDays.first.title, 'author': withDays.first.author, 'days': withDays.first.readingCycleDays};
  }

  Map<String, dynamic>? _computeShortest(List<Book> books) {
    if (books.isEmpty) return null;
    final withDays = books.where((b) => b.readingCycleDays != null && b.readingCycleDays! > 0).toList();
    if (withDays.isEmpty) return null;
    withDays.sort((a, b) => a.readingCycleDays!.compareTo(b.readingCycleDays!));
    return {'title': withDays.first.title, 'author': withDays.first.author, 'days': withDays.first.readingCycleDays};
  }

  List<Map<String, dynamic>> _computeFavoriteAuthors(List<Book> books) {
    final counts = <String, int>{};
    for (final b in books) {
      if (b.author.isNotEmpty) {
        counts[b.author] = (counts[b.author] ?? 0) + 1;
      }
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(3).map((e) => {
      'author': e.key,
      'book_count': e.value,
    }).toList();
  }
}

// ============ 进度环规则提示 ============

class _ProgressRingRuleTip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9DB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE8A0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 16, height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFFFFD43B),
              shape: BoxShape.circle,
            ),
            child: const Center(child: Text('?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '进度环仅在当年且月份筛选为「全部」时显示。选择往年、其他月度或全部生涯时，进度环自动隐藏。',
              style: const TextStyle(fontSize: 11, color: Color(0xFFE67700), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 模块开关 ============

class _ModuleSwitches extends StatelessWidget {
  final bool showFavoriteBooks;
  final bool showLongestShortest;
  final bool showReadList;
  final bool showFavoriteAuthors;
  final Function(String key, bool value) onToggle;

  const _ModuleSwitches({
    required this.showFavoriteBooks,
    required this.showLongestShortest,
    required this.showReadList,
    required this.showFavoriteAuthors,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDEE2E6)),
      ),
      child: Column(
        children: [
          _SwitchRow(
            icon: SvgPicture.asset('assets/icons/stat-icon-fav-books.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(Color(0xFFFF6B6B), BlendMode.srcIn)),
            label: '最爱书籍',
            value: showFavoriteBooks,
            onChanged: (v) => onToggle('favoriteBooks', v),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _SwitchRow(
            icon: const Text('⏱', style: TextStyle(fontSize: 18, color: Color(0xFFFF6B6B))),
            label: '最长与最短',
            value: showLongestShortest,
            onChanged: (v) => onToggle('longestShortest', v),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _SwitchRow(
            icon: SvgPicture.asset('assets/icons/stat-icon-read-list.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(Color(0xFFFF6B6B), BlendMode.srcIn)),
            label: '已读书单',
            value: showReadList,
            onChanged: (v) => onToggle('readList', v),
          ),
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
          _SwitchRow(
            icon: SvgPicture.asset('assets/icons/stat-icon-fav-authors.svg', width: 18, height: 18, colorFilter: const ColorFilter.mode(Color(0xFFFF6B6B), BlendMode.srcIn)),
            label: '最爱作者',
            value: showFavoriteAuthors,
            onChanged: (v) => onToggle('favoriteAuthors', v),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
          SizedBox(
            width: 44,
            height: 24,
            child: GestureDetector(
              onTap: () => onChanged(!value),
              child: Container(
                decoration: BoxDecoration(
                  color: value ? const Color(0xFFFF6B6B) : const Color(0xFFDEE2E6),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(2),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 2)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============ 分享弹窗 ============

class _ShareModal extends StatelessWidget {
  final ui.Image image;
  final File file;
  final VoidCallback onShare;
  final VoidCallback onSave;
  final VoidCallback onEdit;

  const _ShareModal({
    required this.image,
    required this.file,
    required this.onShare,
    required this.onSave,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽条
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFDEE2E6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('分享预览', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          // 预览图
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: RawImage(
                image: image,
                fit: BoxFit.contain,
                width: 360,
                height: 640,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 按钮组
          // 分享到（Primary）
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: onShare,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E8E)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(child: Text('📲 分享到', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white))),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onSave,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                    ),
                    child: const Center(child: Text('💾 保存到相册', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF868E96)))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFDEE2E6)),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Center(child: Text('重新编辑', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF868E96)))),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ============ 输入框字数计数 ============

class _CharInputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final int maxLength;

  const _CharInputField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.maxLength,
  });

  @override
  State<_CharInputField> createState() => _CharInputFieldState();
}

class _CharInputFieldState extends State<_CharInputField> {
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() => _charCount = widget.controller.text.length);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          textInputAction: TextInputAction.done,
          onEditingComplete: () => widget.focusNode.unfocus(),
          onTapOutside: (_) => widget.focusNode.unfocus(),
          maxLength: widget.maxLength,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(color: AppColors.textMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
            counterText: '',
          ),
        ),
        Positioned(
          right: 12,
          bottom: 6,
          child: Text(
            '$_charCount / ${widget.maxLength}',
            style: const TextStyle(fontSize: 11, color: Color(0xFFADB5BD)),
          ),
        ),
      ],
    );
  }
}

// ============ 分享环 Painter ============

class _ShareRingPainter extends CustomPainter {
  final double progress;

  _ShareRingPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;

    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 10
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final fgPaint = Paint()
        ..color = const Color(0xFF51CF66)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress.clamp(0.0, 1.0),
        false,
        fgPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShareRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ==================== 分享统计模块组件 ====================

Color _rankColor(int r) => [
  const Color(0xFFFF6B6B), const Color(0xFF51CF66), const Color(0xFF339AF0), const Color(0xFFCED4DA)
][(r - 1).clamp(0, 3)];

/// 最爱书籍
class _ShareFavBooks extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _ShareFavBooks({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SvgPicture.asset('assets/icons/stat-icon-fav-books.svg', width: 12, height: 12, colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn)),
          const SizedBox(width: 4),
          const Text('最爱书籍', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        const SizedBox(height: 4),
        ...data.map((d) {
          final idx = data.indexOf(d) + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: _rankColor(idx)),
                child: Center(child: Text('$idx', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)))),
              const SizedBox(width: 6),
              Expanded(child: Text('《${d['title']}》', style: const TextStyle(fontSize: 10, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Text('读${d['read_count']}次', style: const TextStyle(fontSize: 9, color: Colors.white60)),
            ]),
          );
        }),
      ]),
    );
  }
}

/// 最长最短（两列并排）
class _ShareDurSection extends StatelessWidget {
  final Map<String, dynamic> longest, shortest;
  const _ShareDurSection({required this.longest, required this.shortest});

  @override
  Widget build(BuildContext context) {
    final lt = longest['title'] as String? ?? '';
    final ld = (longest['days'] as int?) ?? 0;
    final st = shortest['title'] as String? ?? '';
    final sd = (shortest['days'] as int?) ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Text('⏱', style: TextStyle(fontSize: 11, color: Colors.white70)),
          const SizedBox(width: 4),
          const Text('最长与最短', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        const SizedBox(height: 4),
        Row(
          children: [
            // 左列：最长
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📘 最长', style: TextStyle(fontSize: 10, color: Colors.white54)),
                const SizedBox(height: 2),
                Text('《$lt》· ${ld}天', style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ]),
            ),
            // 右列：最短
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📗 最短', style: TextStyle(fontSize: 10, color: Colors.white54)),
                const SizedBox(height: 2),
                Text('《$st》· ${sd}天', style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }
}

/// 已读书单（横向灰色标签，带《》书名号）
class _ShareReadList extends StatelessWidget {
  final List<Book> books;
  const _ShareReadList({required this.books});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SvgPicture.asset('assets/icons/stat-icon-read-list.svg', width: 12, height: 12, colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn)),
          const SizedBox(width: 4),
          const Text('已读书单', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6, runSpacing: 4,
          children: books.map((b) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('《${b.title}》', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          )).toList(),
        ),
      ]),
    );
  }
}

/// 最爱作者
class _ShareFavAuthors extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _ShareFavAuthors({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SvgPicture.asset('assets/icons/stat-icon-fav-authors.svg', width: 12, height: 12, colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn)),
          const SizedBox(width: 4),
          const Text('最爱作者', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
        ]),
        const SizedBox(height: 4),
        ...data.map((d) {
          final idx = data.indexOf(d) + 1;
          return Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(children: [
              Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: _rankColor(idx)),
                child: Center(child: Text('$idx', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)))),
              const SizedBox(width: 6),
              Expanded(child: Text('${d['author']}', style: const TextStyle(fontSize: 10, color: Colors.white70), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Text('${d['book_count']}本', style: const TextStyle(fontSize: 9, color: Colors.white60)),
            ]),
          );
        }),
      ]),
    );
  }
}

// ============ V3.1 数据范围提示横幅 ============

class _DataScopeBanner extends StatelessWidget {
  final BooksProvider booksProvider;

  const _DataScopeBanner({required this.booksProvider});

  @override
  Widget build(BuildContext context) {
    final doneBooks = booksProvider.doneBooks;
    final total = doneBooks.length;
    final years = doneBooks
        .where((b) => b.readDate != null)
        .map((b) => b.readDate!.year)
        .toSet()
        .toList()
      ..sort();

    final minYear = years.isNotEmpty ? years.first : DateTime.now().year;
    final maxYear = years.isNotEmpty ? years.last : DateTime.now().year;
    final yearText = minYear == maxYear ? '覆盖 $minYear 年' : '覆盖 ${minYear}~${maxYear} 年';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9DB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFE8A0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📣', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('当前展示全部年份汇总',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFE67700))),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '共完成 $total 本书 · $yearText',
            style: const TextStyle(fontSize: 12, color: Color(0xFFE67700)),
          ),
          const SizedBox(height: 4),
          const Text(
            '可在下方「分享页展示控制」选择是否显示相应信息',
            style: TextStyle(fontSize: 11, color: Color(0xFFE67700)),
          ),
        ],
      ),
    );
  }
}
