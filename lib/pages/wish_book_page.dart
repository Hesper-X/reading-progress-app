import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/books_provider.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../models/book.dart';
import '../routes/app_routes.dart';

/// 加入想读页 — 按设计稿 07 添加书籍.html「+ 读书清单」模式实现
/// 仅含书名+作者，无封面/日期字段
/// V3.2：新增 editBook 参数支持编辑模式
class WishBookPage extends StatefulWidget {
  final Book? editBook;

  const WishBookPage({super.key, this.editBook});

  @override
  State<WishBookPage> createState() => _WishBookPageState();
}

class _WishBookPageState extends State<WishBookPage> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.editBook?.title);
  late final _authorController = TextEditingController(text: widget.editBook?.author);
  final _titleFocusNode = FocusNode();
  final _authorFocusNode = FocusNode();
  bool _isSaving = false;
  bool _isDeleting = false;

  /// V3.2 编辑模式
  bool get _isEditing => widget.editBook != null;

  @override
  void dispose() {
    _titleFocusNode.dispose();
    _authorFocusNode.dispose();
    _titleController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<BooksProvider>();

    if (_isEditing) {
      // V3.2 编辑模式：调用 updateBook 保留 id
      final success = await provider.updateBook(
        bookId: widget.editBook!.id!,
        title: _titleController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        status: BookStatus.wish,
      );
      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${_titleController.text.trim()}》已更新')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败，请重试')),
          );
        }
      }
    } else {
      // 新建模式：检查免费版限制
      final canAdd = await provider.canAddBook();
      if (!canAdd) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('免费版最多添加 5 本书')),
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
        status: BookStatus.wish,
      );

      if (mounted) {
        setState(() => _isSaving = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${_titleController.text.trim()}》已加入想读')),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败，请重试')),
          );
        }
      }
    }
  }

  /// V3.2 删除书籍（仅编辑模式可用）
  Future<void> _deleteBook() async {
    if (!_isEditing || widget.editBook?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后数据无法恢复，确定要删除这条记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消', style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认删除', style: TextStyle(color: Color(0xFFFF6B6B))),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isDeleting = true);
      final provider = context.read<BooksProvider>();
      final success = await provider.deleteBook(widget.editBook!.id!);
      if (mounted) {
        setState(() => _isDeleting = false);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('《${widget.editBook!.title}》已删除')),
          );
          Navigator.pop(context);
        }
      }
    }
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
              _isEditing ? '编辑想读' : '加入想读',
              style: TextStyle(
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
              const SizedBox(height: 32),

              // === 按钮区域（V3.2 编辑模式双按钮 / 新建模式单按钮）===
              if (_isEditing) ...[                
                // 编辑模式：双按钮并排
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
                                : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
                          ),
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('📋', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 6),
                                      Text('加入想读', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 右侧：删除按钮
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
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B6B)))
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('🗑️', style: TextStyle(fontSize: 16)),
                                      SizedBox(width: 4),
                                      Text('删除', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFFF6B6B))),
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
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('📋', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text('加入想读', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                              ],
                            ),
                    ),
                  ),
                ),
              ],

              // 底部提示
              const SizedBox(height: 24),
              const Text(
                '📖 加入想读后，可以从书架中「想读」标签找到它。准备好阅读时，可以随时将其移至「在读」开始计时。',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 表单标签组件（与 AddBookPage 共享的局部组件）
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
            style: TextStyle(fontSize: 15, color: AppColors.primary),
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
