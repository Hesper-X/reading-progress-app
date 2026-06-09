import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../providers/purchase_provider.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../utils/date_utils.dart' as date_utils;
import '../routes/app_routes.dart';

/// 添加书籍页 / 编辑模式（V3.2）
/// - 新建模式：传入 initialTitle / initialAuthor（可选）
/// - 编辑模式：传入 editBook（完整的 Book 对象，从书架编辑跳转）
class AddBookPage extends StatefulWidget {
  final String? initialTitle;
  final String? initialAuthor;
  final Book? editBook; // V3.2 编辑模式
  final bool isFromWish; // V3.5：从想读页「开始阅读」跳转而来，跳过容量检查

  const AddBookPage({super.key, this.initialTitle, this.initialAuthor, this.editBook, this.isFromWish = false});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _formKey = GlobalKey<FormState>();

  // 获取编辑模式的 book（非空时表示编辑模式）
  Book? get _editBook => widget.editBook;

  late final TextEditingController _titleController;
  late final TextEditingController _authorController;
  final _titleFocusNode = FocusNode();
  final _authorFocusNode = FocusNode();
  late DateTime _startDate;
  String? _coverPath;
  bool _isSaving = false;
  bool _isDeleting = false;

  /// 当前是否为编辑模式
  bool get _isEditing => _editBook != null;

  @override
  void initState() {
    super.initState();
    // 初始化表单数据（编辑模式填入现有数据）
    final edit = widget.editBook;
    _titleController = TextEditingController(text: widget.initialTitle ?? edit?.title ?? '');
    _authorController = TextEditingController(text: widget.initialAuthor ?? edit?.author ?? '');
    _startDate = edit?.startDate ?? DateTime.now();
    _coverPath = edit?.coverPath;
  }

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _authorFocusNode.dispose();
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '选择封面来源',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3E3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt, color: AppColors.primary),
              ),
              title: const Text('拍照'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFE3E3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.photo_library, color: AppColors.primary),
              ),
              title: const Text('从相册选择'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: result);
      if (picked != null) {
        setState(() => _coverPath = picked.path);
      }
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: now.add(const Duration(days: 365)),
      locale: const Locale('zh'),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  /// 保存（新建模式：addBook；编辑模式：updateBook）
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<BooksProvider>();

    if (_isEditing) {
      // 编辑模式：调用 updateBook 保留 id
      final success = await provider.updateBook(
        bookId: _editBook!.id!,
        title: _titleController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        coverPath: _coverPath,
        startDate: _startDate,
        status: _editBook!.status,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${_titleController.text.trim()}》已更新')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败，请重试')),
          );
        }
      }
    } else if (widget.isFromWish) {
      // 从想读→在读跳转而来：直接保存，跳过容量检查
      final success = await provider.addBook(
        title: _titleController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        coverPath: _coverPath,
        startDate: _startDate,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${_titleController.text.trim()}》已加入在读')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败，请重试')),
          );
        }
      }
      return;
    } else {
      // 新建模式：检查免费版限制
      final isPro = context.read<PurchaseProvider>().isPro;
      final canAdd = await provider.canAddBook(isPro: isPro);
      if (!canAdd) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('基础版最多保存 5 本书，升级 Pro 版无限添加')),
          );
          Navigator.pushNamed(context, AppRoutes.pro);
        }
        setState(() => _isSaving = false);
        return;
      }

      final success = await provider.addBook(
        title: _titleController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        coverPath: _coverPath,
        startDate: _startDate,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${_titleController.text.trim()}》已加入在读')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败，请重试')),
          );
        }
      }
    }
  }

  /// 删除书籍（仅编辑模式可用）
  Future<void> _deleteBook() async {
    if (!_isEditing || _editBook?.id == null) return;

    // 确认删除弹窗
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后数据无法恢复，确定要删除这条记录吗？'),
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
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('确认删除',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      final provider = context.read<BooksProvider>();
      final success = await provider.deleteBook(_editBook!.id!);
      if (mounted) {
        setState(() => _isDeleting = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${_editBook!.title}》已删除')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('删除失败，请重试')),
          );
        }
      }
    }
  }

  /// 根据编辑模式状态获取页面标题
  String get _pageTitle {
    if (!_isEditing) return '开始阅读';
    switch (_editBook!.status) {
      case BookStatus.wish:
        return '编辑想读';
      case BookStatus.reading:
        return '编辑在读';
      default:
        return '编辑';
    }
  }

  /// 获取底部主按钮的文字和图标（编辑模式缩小；新建模式保持原样）
  String get _primaryButtonLabel {
    if (!_isEditing) return '开始阅读';
    return _editBook!.status == BookStatus.wish ? '📋 加入想读' : '📖 开始阅读';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFFDEE2E6), width: 1),
        ),
        automaticallyImplyLeading: false,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text(
                  '←',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _pageTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === 封面（可选）===
              _FormLabel(
                text: '封面',
                suffix: '（可选）',
                isOptional: true,
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickCover,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFDEE2E6), width: 2, strokeAlign: BorderSide.strokeAlignInside),
                  ),
                  child: _coverPath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(_coverPath!),
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, size: 28, color: Color(0xFFADB5BD)),
                            SizedBox(height: 8),
                            Text(
                              '点击上传封面',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFFADB5BD),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),

              // === 书名（必填）===
              _FormLabel(text: '书名', required: true),
              const SizedBox(height: 8),
              Stack(
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) => _titleFocusNode.unfocus(),
                    decoration: InputDecoration(
                      hintText: '输入书名',
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
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      counterText: '',
                    ),
                    maxLength: AppConstants.maxTitleLength,
                    autofocus: true,
                  ),
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: ListenableBuilder(
                      listenable: _titleController,
                      builder: (context, _) {
                        return Text(
                          '${_titleController.text.length} / ${AppConstants.maxTitleLength}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFADB5BD)),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === 作者（可选）===
              _FormLabel(text: '作者', suffix: '（可选）', isOptional: true),
              const SizedBox(height: 8),
              Stack(
                children: [
                  TextField(
                    controller: _authorController,
                    focusNode: _authorFocusNode,
                    textInputAction: TextInputAction.done,
                    onEditingComplete: () => _authorFocusNode.unfocus(),
                    onTapOutside: (_) => _authorFocusNode.unfocus(),
                    decoration: InputDecoration(
                      hintText: '输入作者',
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
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                      counterText: '',
                    ),
                    maxLength: AppConstants.maxAuthorLength,
                  ),
                  Positioned(
                    right: 12,
                    bottom: 8,
                    child: ListenableBuilder(
                      listenable: _authorController,
                      builder: (context, _) {
                        return Text(
                          '${_authorController.text.length} / ${AppConstants.maxAuthorLength}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFFADB5BD)),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === 开始阅读日期（必填）===
              _FormLabel(text: '开始阅读日期', required: true),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDEE2E6)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        date_utils.DateUtils.formatChinese(_startDate),
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const Text(
                        '▾',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // === 底部按钮 ===
              // V3.2 编辑模式：双按钮并排
              // 新建模式：单按钮全宽
              if (_isEditing) ...[
                // 编辑模式：双按钮
                Row(
                  children: [
                    // 左侧：保存按钮（缩小）
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: (_isSaving || _isDeleting) ? null : _save,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: _isSaving
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(_primaryButtonLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 右侧：删除按钮（粉色背景 + 红色边框 + 红色文字）
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: (_isSaving || _isDeleting) ? null : _deleteBook,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFC9C9), width: 1.5),
                          ),
                          child: Center(
                            child: _isDeleting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFFFF6B6B),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('🗑️', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 4),
                                      Text(
                                        '删除',
                                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B)),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // 新建模式：单按钮全宽
                GestureDetector(
                  onTap: _isSaving ? null : _save,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _isSaving
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
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
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('📖', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text(
                                  '开始阅读',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 表单标签组件
class _FormLabel extends StatelessWidget {
  final String text;
  final bool required;
  final String? suffix;
  final bool isOptional;

  const _FormLabel({
    required this.text,
    this.required = false,
    this.suffix,
    this.isOptional = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.primary,
            ),
          ),
        if (suffix != null)
          Text(
            suffix!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
      ],
    );
  }
}
