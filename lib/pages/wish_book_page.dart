import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    hide InputImageRotation;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/books_provider.dart';
import '../providers/purchase_provider.dart';
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
  final _picker = ImagePicker();

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

  // ============ V3.5 OCR 拍照取书名（本地 ML Kit） ============

  Future<void> _takePhotoForOcr() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo == null) return;

      // 用拍照的图片进行本地 OCR 识别
      final result = await _localOcr(File(photo.path));

      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        _titleController.text = result;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📖 已识别书名，请确认是否正确'),
            duration: Duration(milliseconds: 2500),
          ),
        );
      } else {
        _showOcrFailDialog();
      }
    } catch (e) {
      if (mounted) _showOcrFailDialog();
    }
  }

  /// 本地 OCR 识别（Google ML Kit Text Recognition）
  /// 纯本地运行，图片不离开设备
  Future<String?> _localOcr(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.chinese);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final recognizedText = await textRecognizer.processImage(inputImage);
      final blocks = recognizedText.blocks;

      if (blocks.isEmpty) return null;

      // 提取所有识别到的文本行，取最长文本作为最可能的书名
      String best = '';
      for (final block in blocks) {
        for (final line in block.lines) {
          if (line.text.length > best.length) {
            best = line.text;
          }
        }
      }
      return best.isNotEmpty ? best.trim() : null;
    } finally {
      textRecognizer.close();
    }
  }

  void _showOcrFailDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('识别失败'),
        content: const Text('未能识别到书名'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _takePhotoForOcr();
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(21)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('重试', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _titleFocusNode.requestFocus();
            },
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFF868E96),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(21),
                side: const BorderSide(color: Color(0xFFDEE2E6)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('手动输入', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF868E96))),
          ),
        ],
      ),
    );
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
              Row(
                children: [
                  _FormLabel(text: '书名', required: true),
                  const Spacer(),
                  GestureDetector(
                    onTap: _takePhotoForOcr,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFFFF0F0),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Color(0xFFFFC9C9), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('📷', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text('拍照取书名', style: TextStyle(fontSize: 12, color: Color(0xFFFF6B6B), fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Stack(
                children: [
                  TextField(
                    controller: _titleController,
                    focusNode: _titleFocusNode,
                    textInputAction: TextInputAction.next,
                    onTapOutside: (_) => _titleFocusNode.unfocus(),
                    decoration: InputDecoration(
                      hintText: '拍照可自动填充书名',
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
