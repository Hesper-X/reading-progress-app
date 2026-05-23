import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';
import '../utils/date_utils.dart' as date_utils;

/// 07_3 添加已读书籍（V3.3 双模式：新增 + 编辑）
///
/// 入口：
///  - 新增：书架页已读Tab → 「+ 标记已读」横条
///  - 编辑：已读卡片 → 「编辑」按钮（传入 editBook）
///
/// 编辑模式：预填数据、封面可替换、保留原id、支持保存/删除
class AddDoneBookPage extends StatefulWidget {
  final Book? editBook;

  const AddDoneBookPage({super.key, this.editBook});

  bool get isEdit => editBook != null;

  @override
  State<AddDoneBookPage> createState() => _AddDoneBookPageState();
}

class _AddDoneBookPageState extends State<AddDoneBookPage> {
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  final _imagePicker = ImagePicker();

  String? _coverPath;
  bool _hasCover = false;
  DateTime _readDate = DateTime.now();
  int _rating = 0;
  bool _isSaving = false;
  bool _showSuccess = false;
  Book? _originalBook; // 编辑模式保留原对象

  @override
  void initState() {
    super.initState();
    final editBook = widget.editBook;
    if (editBook != null) {
      _originalBook = editBook;
      _titleController.text = editBook.title;
      _authorController.text = editBook.author;
      if (editBook.coverPath != null && editBook.coverPath!.isNotEmpty) {
        _coverPath = editBook.coverPath;
        _hasCover = true;
      }
      _rating = editBook.rating?.round() ?? 0;
      if (editBook.readDate != null) _readDate = editBook.readDate!;
      if (editBook.notes != null) _notesController.text = editBook.notes!;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  // ============ 封面选取 ============

  void _showCoverPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('选择封面',
                  style: TextStyle(fontSize: 14, color: Color(0xFF868E96))),
              const SizedBox(height: 16),
              _SheetButton(
                icon: '📷',
                label: '拍照',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 4),
              _SheetButton(
                icon: '🖼️',
                label: '从相册选取',
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Text('取消',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212529))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 1040,
        imageQuality: 85,
      );
      if (picked != null) {
        if (mounted) {
          setState(() {
            _coverPath = picked.path;
            _hasCover = true;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选取封面失败: $e')),
        );
      }
    }
  }

  // ============ 日期选择 ============

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _readDate,
      firstDate: DateTime(2000),
      lastDate: now,
      locale: const Locale('zh'),
    );
    if (picked != null) {
      setState(() => _readDate = picked);
    }
  }

  // ============ 校验与保存 ============

  Future<void> _save() async {
    // 校验
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入书名')),
      );
      return;
    }
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先评分')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<BooksProvider>();

    if (widget.isEdit && _originalBook != null) {
      // ══ 编辑模式：UPDATE，保留原id ══
      try {
        await provider.updateBook(
          bookId: _originalBook!.id!,
          title: title,
          author: _authorController.text.trim(),
          coverPath: _coverPath,
          rating: _rating.toDouble(),
          notes: _notesController.text.trim().isEmpty
              ? null
              : _notesController.text.trim(),
          readDate: _readDate,
        );
        if (mounted) {
          setState(() => _isSaving = false);
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSaving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('保存失败: $e')),
          );
        }
      }
      return;
    }

    // ══ 新增模式：INSERT ══
    final book = Book(
      id: null, // 由 insert 自动分配
      title: title,
      author: _authorController.text.trim(),
      coverPath: _coverPath,
      rating: _rating.toDouble(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      readDate: _readDate,
      startDate: _readDate,
      status: BookStatus.done,
      finishedAt: DateTime.now(),
      readCount: 1,
      createdAt: DateTime.now(),
    );

    try {
      await provider.addDoneBook(book);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _showSuccess = true;
        });

        // 2 秒后自动返回书架
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;
          Navigator.pop(context, true);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  // ============ 删除（编辑模式） ============

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除？'),
        content: const Text('删除后无法恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFDEE2E6)),
              ),
            ),
            child: const Text('取消',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除',
                style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && _originalBook?.id != null && mounted) {
      await context.read<BooksProvider>().deleteBook(_originalBook!.id!);
      if (mounted) Navigator.pop(context, true);
    }
  }

  // ============ 返回确认 ============

  Future<bool> _onWillPop() async {
    if (_showSuccess) return true;
    final hasContent = _titleController.text.trim().isNotEmpty ||
        _authorController.text.trim().isNotEmpty ||
        _notesController.text.trim().isNotEmpty ||
        _hasCover ||
        _rating > 0;

    if (!hasContent) return true;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确定离开？'),
        content: const Text('未保存的内容将丢失'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: Color(0xFFDEE2E6)),
              ),
            ),
            child: const Text('留下',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('离开',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: _showSuccess
            ? null
            : AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                automaticallyImplyLeading: false,
                shape: const Border(
                  bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1),
                ),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () => _onWillPop().then((shouldPop) {
                        if (shouldPop && mounted) Navigator.pop(context);
                      }),
                      child: const Padding(
                        padding: EdgeInsets.only(bottom: 3),
                        child: Text('←',
                            style: TextStyle(
                                fontSize: 20,
                                color: AppColors.textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(widget.isEdit ? '编辑已读书籍' : '添加已读书籍',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ],
                ),
              ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ══ 封面区域（可选）══
                  _buildCoverSection(),
                  const SizedBox(height: 24),

                  // ══ 书名（必填）══
                  _buildFormLabel('书名', required: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('请输入书名'),
                    maxLength: 50,
                  ),
                  const SizedBox(height: 24),

                  // ══ 作者（可选）══
                  _buildFormLabel('作者', optional: true),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _authorController,
                    textInputAction: TextInputAction.next,
                    decoration: _inputDecoration('请输入作者'),
                    maxLength: 30,
                  ),
                  const SizedBox(height: 24),

                  // ══ 读完日期（必填）══
                  _buildFormLabel('读完日期', required: true),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _selectDate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFDEE2E6)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            date_utils.DateUtils.formatChinese(_readDate),
                            style: const TextStyle(
                                fontSize: 16,
                                color: AppColors.textPrimary),
                          ),
                          const Text('▾',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('默认为今天，可调整到过去的日期',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 24),

                  // ══ 评分（必填）══
                  _buildFormLabel('评分', required: true),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (i) {
                      final starIndex = i + 1;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starIndex),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 150),
                            style: TextStyle(
                              fontSize: 36,
                              color: starIndex <= _rating
                                  ? const Color(0xFFFFD43B)
                                  : const Color(0xFFDEE2E6),
                            ),
                            child: const Text('★'),
                          ),
                        ),
                      );
                    }),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('点击星星评分，读完了一定要给个评价吧~',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ),
                  const SizedBox(height: 24),

                  // ══ 感想（可选）══
                  _buildFormLabel('感想', optional: true),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      TextField(
                        controller: _notesController,
                        focusNode: _notesFocusNode,
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () => _notesFocusNode.unfocus(),
                        onTapOutside: (_) => _notesFocusNode.unfocus(),
                        decoration: InputDecoration(
                          hintText: '记录此刻的感受...',
                          hintStyle:
                              const TextStyle(color: AppColors.textMuted),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFDEE2E6)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFDEE2E6)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          counterText: '',
                        ),
                        maxLength: AppConstants.maxNotesLength,
                        maxLines: 3,
                        minLines: 3,
                      ),
                      Positioned(
                        right: 12,
                        bottom: 8,
                        child: ListenableBuilder(
                          listenable: _notesController,
                          builder: (context, _) {
                            return Text(
                              '${_notesController.text.length} / ${AppConstants.maxNotesLength}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFADB5BD)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildBottomButtons(),
                  const SizedBox(height: 32),
                ],
              ),
            ),

            // ══ 成功反馈动画（仅新增模式）══
            if (_showSuccess)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.95),
                  child: Center(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(scale: value, child: child);
                      },
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('✅',
                              style: TextStyle(fontSize: 80,
                                  color: Color(0xFF51CF66))),
                          SizedBox(height: 16),
                          Text('记录成功！',
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                          SizedBox(height: 8),
                          Text('已加入已读书架',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary)),
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
  }

  // ============ 构建子组件 ============

  Widget _buildCoverSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('封面',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(width: 4),
            const Text('（可选）',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 封面占位块
            GestureDetector(
              onTap: _showCoverPicker,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 80,
                height: 104,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _hasCover
                        ? Colors.transparent
                        : const Color(0xFFD0D5DD),
                    width: 2,
                  ),
                  color: _hasCover ? null : Colors.white,
                  gradient: _hasCover
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFE3E3), Color(0xFFFFD3D3)],
                        )
                      : null,
                ),
                child: _hasCover && _coverPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: _coverPath!.startsWith('/')
                            ? Image.file(
                                File(_coverPath!),
                                width: 80,
                                height: 104,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderContent(),
                              )
                            : Image.asset(
                                _coverPath!,
                                width: 80,
                                height: 104,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderContent(),
                              ),
                      )
                    : _buildPlaceholderContent(),
              ),
            ),
            const SizedBox(width: 16),
            // 右侧提示文字
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(fontSize: 13, color: Color(0xFFADB5BD), height: 1.5),
                  children: [
                    if (_hasCover) ...[
                      const TextSpan(text: '已添加封面'),
                      const TextSpan(text: '\n点击左侧 ', children: [
                        TextSpan(
                          text: '替换封面',
                          style: const TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                    ] else ...[
                      const TextSpan(text: '点击左侧添加封面'),
                      const TextSpan(text: '\n支持 ', children: [
                        TextSpan(
                          text: '拍照',
                          style: const TextStyle(
                              color: Color(0xFFFF6B6B),
                              fontWeight: FontWeight.w500),
                        ),
                      ]),
                      const TextSpan(text: ' 或从 '),
                      const TextSpan(
                        text: '相册',
                        style: TextStyle(
                            color: Color(0xFFFF6B6B),
                            fontWeight: FontWeight.w500),
                      ),
                      const TextSpan(text: ' 选取'),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ══ 底部按钮：新增模式单按钮，编辑模式双按钮并排 ══
  Widget _buildBottomButtons() {
    if (widget.isEdit) {
      // 编辑模式：💾 保存 + 🗑 删除 并排一行
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            // 保存按钮
            Expanded(
              child: GestureDetector(
                onTap: _isSaving ? null : _save,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _isSaving
                        ? null
                        : [
                            BoxShadow(
                              color: const Color(0xFFFF6B6B)
                                  .withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                  ),
                  child: Center(
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('💾',
                                  style: TextStyle(fontSize: 18)),
                              SizedBox(width: 8),
                              Text('保存',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white)),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // 删除按钮
            Expanded(
              child: GestureDetector(
                onTap: _delete,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFC9C9)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🗑️', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 8),
                      Text('删除',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF868E96))),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // 新增模式：✅ 标记读完 单按钮
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFF6B6B),
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isSaving
              ? null
              : [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B)
                        .withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('✅',
                        style: TextStyle(fontSize: 18)),
                    SizedBox(width: 8),
                    Text('标记读完',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildPlaceholderContent() {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt, size: 28, color: Color(0xFFADB5BD)),
        SizedBox(height: 6),
        Text('添加封面',
            style: TextStyle(fontSize: 12, color: Color(0xFFADB5BD))),
      ],
    );
  }

  Widget _buildFormLabel(String text,
      {bool required = false, bool optional = false}) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        if (required)
          const Text(' *',
              style:
                  TextStyle(fontSize: 15, color: AppColors.primary)),
        if (optional)
          const Text('（可选）',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w400)),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDEE2E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.all(14),
      counterText: '',
    );
  }
}

/// Action Sheet 选项按钮
class _SheetButton extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _SheetButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          foregroundColor: const Color(0xFF212529),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
