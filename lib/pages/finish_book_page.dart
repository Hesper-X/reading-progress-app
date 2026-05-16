import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/book.dart';
import '../providers/books_provider.dart';
import '../theme/colors.dart';
import '../constants/app_constants.dart';
import '../routes/app_routes.dart';
import '../utils/date_utils.dart' as date_utils;

/// 标记完读页（第二步：完成阅读）— 按设计稿 07_2 标记读完.html 实现
class FinishBookPage extends StatefulWidget {
  final Book book;

  const FinishBookPage({super.key, required this.book});

  @override
  State<FinishBookPage> createState() => _FinishBookPageState();
}

class _FinishBookPageState extends State<FinishBookPage> {
  late DateTime _readDate;
  int _rating = 0;
  final _notesController = TextEditingController();
  final _notesFocusNode = FocusNode();
  bool _isSaving = false;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    _readDate = DateTime.now();
  }

  @override
  void dispose() {
    _notesFocusNode.dispose();
    _notesController.dispose();
    super.dispose();
  }

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

  Future<void> _save() async {
    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请评分')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<BooksProvider>();
    final success = await provider.markAsDone(
      bookId: widget.book.id!,
      readDate: _readDate,
      rating: _rating.toDouble(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        setState(() => _showSuccess = true);
        Future.delayed(const Duration(seconds: 2), () {
          if (!mounted) return;

          final provider = context.read<BooksProvider>();
          final isGoalMet = provider.currentYearCount >= provider.yearlyGoal &&
              provider.yearlyGoal > 0;

          if (isGoalMet && !provider.celebrationTriggered) {
            // 清空路由栈并回到首页（MainShell 会监听 provider 弹庆祝）
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.home,
              (route) => false,
            );
          } else {
            if (Navigator.of(context).canPop()) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, AppRoutes.library);
            }
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存失败，请重试')),
        );
      }
    }
  }

  Future<void> _confirmAbandon() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('放弃阅读《${widget.book.title}》？'),
        content: const Text('该书籍将从在读书架移除，不计入统计数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('继续阅读',
                style: TextStyle(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定放弃',
                style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<BooksProvider>();
      await provider.abandonBook(widget.book.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已放弃阅读《${widget.book.title}》')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final readingCycle = widget.book.elapsedDays;

    return Scaffold(
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
                    '标记读完',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
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
                // === 书籍信息头（只读）===
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 封面占位
                    Container(
                      width: 80,
                      height: 104,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFFFE3E3), Color(0xFFFFD3D3)],
                        ),
                      ),
                      child: const Center(
                        child: Text('📖', style: TextStyle(fontSize: 36)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // 书籍信息
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.book.author != null &&
                              widget.book.author!.isNotEmpty)
                            Text(
                              widget.book.author!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _ReadingTag(
                                  text:
                                      '开始阅读：${widget.book.formattedStartDate}'),
                              const SizedBox(width: 8),
                              _ReadingTag(text: '已读 $readingCycle 天'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // 分割线
                const Divider(height: 1, color: Color(0xFFF1F3F5)),
                const SizedBox(height: 24),

                // === 读完日期（必填）===
                _FormLabel(text: '读完日期', required: true),
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
                          date_utils.DateUtils.formatChinese(_readDate),
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
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '默认为今天，可调整到过去的日期',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // === 评分（必填）===
                _FormLabel(text: '评分', required: true),
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
                  child: Text(
                    '点击星星评分，读完了一定要给个评价吧~',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // === 感想（可选）===
                _FormLabel(text: '感想', suffix: '（可选）', isOptional: true),
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
                            style: const TextStyle(fontSize: 12, color: Color(0xFFADB5BD)),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // === 标记读完按钮 ===
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
                                color:
                                    AppColors.primary.withValues(alpha: 0.3),
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
                                Text('✅', style: TextStyle(fontSize: 18)),
                                SizedBox(width: 8),
                                Text(
                                  '标记读完',
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

                // === 放弃阅读 ===
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _confirmAbandon,
                    child: Text(
                      '放弃阅读《${widget.book.title}》',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // === 成功反馈动画 ===
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
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '✅',
                          style: TextStyle(fontSize: 80),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '恭喜读完！',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '《${widget.book.title}》已加入已读书架',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
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
    );
  }
}

/// 书籍信息标签
class _ReadingTag extends StatelessWidget {
  final String text;

  const _ReadingTag({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.primary,
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
