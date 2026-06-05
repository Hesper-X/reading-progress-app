import 'package:flutter/material.dart';
import '../models/book.dart';
import '../models/checkin.dart';
import '../theme/colors.dart';

// ============================================================
// Dialog 1：新建打卡（点击今日·未打卡）
// ============================================================

/// 新建打卡 Dialog
class CheckinNewDialog extends StatefulWidget {
  final String dateStr;
  final List<Book> readingBooks;
  final Future<void> Function(int bookId, int? durationMin, String? note)
      onSubmit;

  const CheckinNewDialog({
    super.key,
    required this.dateStr,
    required this.readingBooks,
    required this.onSubmit,
  });

  @override
  State<CheckinNewDialog> createState() => _CheckinNewDialogState();
}

class _CheckinNewDialogState extends State<CheckinNewDialog> {
  int? _selectedBookId;
  int? _selectedHour;
  int _selectedMinute = 0;
  final _noteController = TextEditingController();
  final _noteFocusNode = FocusNode();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    _noteFocusNode.dispose();
    super.dispose();
  }

  bool get _canSubmit => _selectedBookId != null && !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    final totalMin =
        (_selectedHour ?? 0) * 60 + _selectedMinute;
    await widget.onSubmit(
      _selectedBookId!,
      totalMin > 0 ? totalMin : null,
      _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );
  }

  // 格式化日期显示
  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${int.parse(parts[0])}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  @override
  Widget build(BuildContext context) {
    return _DialogContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _DialogTitle(
            title: '☀️ 阅读打卡',
            dateSubtitle: _formatDate(widget.dateStr),
            onClose: () => Navigator.pop(context),
          ),

          const SizedBox(height: 16),

          // 在读书籍下拉
          _BookSelector(
            books: widget.readingBooks,
            selectedBookId: _selectedBookId,
            onChanged: (id) => setState(() => _selectedBookId = id),
          ),

          const SizedBox(height: 16),

          // 阅读时长双下拉
          _DurationSelector(
            selectedHour: _selectedHour,
            selectedMinute: _selectedMinute,
            onHourChanged: (h) => setState(() => _selectedHour = h),
            onMinuteChanged: (m) => setState(() => _selectedMinute = m),
          ),

          const SizedBox(height: 16),

          // 笔记输入框
          _NoteInput(
            controller: _noteController,
            focusNode: _noteFocusNode,
          ),

          const SizedBox(height: 16),

          // 提交按钮
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '☀️ 打卡',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dialog 2：更新打卡（点击今日·已打卡）
// ============================================================

class CheckinUpdateDialog extends StatefulWidget {
  final String dateStr;
  final List<Book> readingBooks;
  final CheckinDetail? lastCheckin;
  final Future<void> Function(int bookId, int? durationMin, String? note)
      onSubmit;

  const CheckinUpdateDialog({
    super.key,
    required this.dateStr,
    required this.readingBooks,
    this.lastCheckin,
    required this.onSubmit,
  });

  @override
  State<CheckinUpdateDialog> createState() => _CheckinUpdateDialogState();
}

class _CheckinUpdateDialogState extends State<CheckinUpdateDialog> {
  int? _selectedBookId;
  int? _selectedHour;
  int _selectedMinute = 0;
  final _noteController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 保留上次打卡的输入
    if (widget.lastCheckin != null) {
      _selectedBookId = widget.lastCheckin!.bookId;
      final total = widget.lastCheckin!.durationMin ?? 0;
      _selectedHour = total ~/ 60;
      // 小时下拉items从null开始，0小时用null表示
      if (_selectedHour == 0) _selectedHour = null;
      _selectedMinute = total % 60;
      // 分钟下拉步长为5，把非5倍数的值就近取整
      _selectedMinute = (_selectedMinute ~/ 5) * 5;
      if (widget.lastCheckin!.note != null) {
        _noteController.text = widget.lastCheckin!.note!;
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  bool get _canSubmit => _selectedBookId != null && !_isSubmitting;

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${int.parse(parts[0])}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _isSubmitting = true);

    final totalMin = (_selectedHour ?? 0) * 60 + _selectedMinute;
    await widget.onSubmit(
      _selectedBookId!,
      totalMin > 0 ? totalMin : null,
      _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // 已有记录提示文字
    String existingHint = '';
    if (widget.lastCheckin != null &&
        widget.lastCheckin!.durationMin != null &&
        widget.lastCheckin!.durationMin! > 0) {
      final lastTotal = widget.lastCheckin!.durationMin!;
      final h = lastTotal ~/ 60;
      final m = lastTotal % 60;
      if (h > 0 && m > 0) {
        existingHint = '已有记录: ${h}小时${m}分钟(已累积)，点击更新将追加新记录';
      } else if (h > 0) {
        existingHint = '已有记录: ${h}小时(已累积)，点击更新将追加新记录';
      } else {
        existingHint = '已有记录: ${m}分钟(已累积)，点击更新将追加新记录';
      }
    } else if (widget.lastCheckin != null &&
        widget.lastCheckin!.note != null &&
        widget.lastCheckin!.note!.isNotEmpty) {
      existingHint = '已有笔记记录，点击更新将追加新记录';
    }

    return _DialogContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _DialogTitle(
            title: '☀️ 更新打卡',
            dateSubtitle: '${_formatDate(widget.dateStr)} · 已打卡',
            onClose: () => Navigator.pop(context),
          ),

          const SizedBox(height: 16),

          // 在读书籍下拉
          _BookSelector(
            books: widget.readingBooks,
            selectedBookId: _selectedBookId,
            onChanged: (id) => setState(() => _selectedBookId = id),
          ),

          const SizedBox(height: 16),

          // 阅读时长双下拉
          _DurationSelector(
            selectedHour: _selectedHour,
            selectedMinute: _selectedMinute,
            onHourChanged: (h) => setState(() => _selectedHour = h),
            onMinuteChanged: (m) => setState(() => _selectedMinute = m),
          ),

          if (existingHint.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              existingHint,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 笔记输入框
          _NoteInput(
            controller: _noteController,
            focusNode: null,
          ),

          const SizedBox(height: 16),

          // 提交按钮
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.border,
                disabledForegroundColor: Colors.white70,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(21),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      '☀️ 更新打卡',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Dialog 3：打卡详情（过往已打卡日期·只读）
// ============================================================

class CheckinDetailDialog extends StatelessWidget {
  final CheckinDaySummary summary;

  const CheckinDetailDialog({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return _DialogContainer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题栏
          _DialogTitle(
            title: '📅 ${_formatDate(summary.details.first.checkinDate)} · '
                '已打卡',
            onClose: () => Navigator.pop(context),
          ),

          if (summary.streakDays > 0) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '🔥 连续阅读: ${summary.streakDays} 天(截至当天)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 当天记录列表
          ...summary.details.map((detail) {
            final bookTitle =
                summary.bookTitles[detail.bookId] ?? '未知书籍';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _RecordCard(
                bookTitle: bookTitle,
                durationStr: detail.formattedDuration,
                note: detail.note,
              ),
            );
          }),

          // 当日合计
          if (summary.totalMinutes > 0) ...[
            const Divider(color: Color(0xFFF1F3F5), thickness: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  '当日累计',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  summary.formattedTotalDuration,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // 关闭按钮
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                backgroundColor: const Color(0xFFF1F3F5),
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                '关闭',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    final parts = dateStr.split('-');
    if (parts.length != 3) return dateStr;
    return '${int.parse(parts[0])}年${int.parse(parts[1])}月${int.parse(parts[2])}日';
  }
}

// ============================================================
// 通用子组件
// ============================================================

/// Dialog 容器（底部弹出，圆角背景）
class _DialogContainer extends StatelessWidget {
  final Widget child;

  const _DialogContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + bottomInset),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          child: child,
        ),
      ),
    );
  }
}

/// Dialog 标题栏
class _DialogTitle extends StatelessWidget {
  final String title;
  final String? dateSubtitle;
  final VoidCallback? onClose;

  const _DialogTitle({
    required this.title,
    this.dateSubtitle,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (onClose != null)
              GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F3F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Color(0xFF868E96)),
                ),
              ),
          ],
        ),
        if (dateSubtitle != null && dateSubtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            dateSubtitle!,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }
}

/// 在读书籍下拉选择器
class _BookSelector extends StatelessWidget {
  final List<Book> books;
  final int? selectedBookId;
  final ValueChanged<int?> onChanged;

  const _BookSelector({
    required this.books,
    required this.selectedBookId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('📖', style: TextStyle(fontSize: 14)),
            SizedBox(width: 4),
            Text(
              '在读书籍',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border, width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: selectedBookId,
              isExpanded: true,
              hint: const Text(
                '请选择在读书籍',
                style: TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              items: books.map((book) {
                return DropdownMenuItem(
                  value: book.id,
                  child: Text(
                    '📖 ${book.title}',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// 阅读时长双下拉选择（小时 + 分钟）
class _DurationSelector extends StatelessWidget {
  final int? selectedHour;
  final int selectedMinute;
  final ValueChanged<int?> onHourChanged;
  final ValueChanged<int> onMinuteChanged;

  const _DurationSelector({
    required this.selectedHour,
    required this.selectedMinute,
    required this.onHourChanged,
    required this.onMinuteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('⏱', style: TextStyle(fontSize: 14)),
            SizedBox(width: 4),
            Text(
              '阅读时长(选填)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                value: selectedHour,
                hint: '小时',
                items: [null, ...List.generate(24, (i) => i + 1)],
                itemLabel: (v) => v == null ? '0小时' : '$v小时',
                onChanged: onHourChanged,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDropdown(
                value: selectedMinute,
                hint: '分钟',
                items: List.generate(13, (i) => i * 5),
                itemLabel: (v) => v == 0 ? '0分钟' : '${v}分钟',
                onChanged: (v) => onMinuteChanged(v ?? 0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T?> items,
    required String Function(T?) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                itemLabel(item),
                style: const TextStyle(fontSize: 14),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

/// 笔记输入框（含字数计数）
class _NoteInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;

  const _NoteInput({
    required this.controller,
    this.focusNode,
  });

  @override
  State<_NoteInput> createState() => _NoteInputState();
}

class _NoteInputState extends State<_NoteInput> {
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    _charCount = widget.controller.text.length;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {
      _charCount = widget.controller.text.length;
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Text('📝', style: TextStyle(fontSize: 14)),
            SizedBox(width: 4),
            Text(
              '阅读笔记(选填)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            TextField(
              controller: widget.controller,
              focusNode: widget.focusNode,
              maxLength: 200,
              maxLines: 3,
              minLines: 3,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '笔记、书签(记录读书进度)...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade400,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                counterText: '',
                contentPadding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              ),
            ),
            Positioned(
              bottom: 8,
              right: 10,
              child: Text(
                '$_charCount/200',
                style: TextStyle(
                  fontSize: 11,
                  color: _charCount == 200
                      ? AppColors.primary
                      : const Color(0xFFADB5BD),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 记录卡片（详情 Dialog 内用）
class _RecordCard extends StatelessWidget {
  final String bookTitle;
  final String? durationStr;
  final String? note;

  const _RecordCard({
    super.key,
    required this.bookTitle,
    this.durationStr,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '📖 $bookTitle',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (durationStr != null && durationStr!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    durationStr!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            note != null && note!.isNotEmpty
                ? note!
                : '(当日无笔记)',
            style: TextStyle(
              fontSize: 13,
              color: note != null && note!.isNotEmpty
                  ? const Color(0xFF495057)
                  : const Color(0xFFADB5BD),
              fontStyle:
                  note != null && note!.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
