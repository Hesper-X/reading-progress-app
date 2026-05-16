import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/books_provider.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../utils/date_utils.dart' as date_utils;
import '../routes/app_routes.dart';

/// 添加书籍页（第一步：开始阅读）— 按设计稿 07 添加书籍.html 实现
class AddBookPage extends StatefulWidget {
  final String? initialTitle;
  final String? initialAuthor;

  const AddBookPage({super.key, this.initialTitle, this.initialAuthor});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.initialTitle);
  late final _authorController = TextEditingController(text: widget.initialAuthor);
  final _titleFocusNode = FocusNode();
  final _authorFocusNode = FocusNode();
  DateTime _startDate = DateTime.now();
  String? _coverPath;
  bool _isSaving = false;

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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<BooksProvider>();

    // 检查免费版限制
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
            const Text(
              '开始阅读',
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

              // === 开始阅读按钮 ===
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
