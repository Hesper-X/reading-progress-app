import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../models/book.dart';
import '../repositories/book_repository.dart';
import '../databases/database_helper.dart';

/// 数据导出服务
class ExportService {
  static final ExportService instance = ExportService._init();
  final BookRepository _repo = BookRepository(DatabaseHelper.instance);

  ExportService._init();

  /// 导出为 JSON
  Future<void> exportJson() async {
    final books = await _repo.getFinishedBooks();
    final json = _toJson(books);
    final file = File('${Directory.systemTemp.path}/reading_progress.json');
    await file.writeAsString(json);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '读书进度条数据',
      ),
    );
  }

  /// 导出为 CSV
  Future<void> exportCsv() async {
    final books = await _repo.getFinishedBooks();
    final csv = _toCsv(books);
    final file = File('${Directory.systemTemp.path}/reading_progress.csv');
    await file.writeAsString(csv);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: '读书进度条数据',
      ),
    );
  }

  String _toJson(List<Book> books) {
    final buffer = StringBuffer('[\n');
    for (int i = 0; i < books.length; i++) {
      final b = books[i];
      buffer.write(
          '  {"id":${b.id},"title":"${_escape(b.title)}","author":"${_escape(b.author ?? "")}",'
          '"rating":${b.rating ?? 0},"notes":"${_escape(b.notes ?? "")}",'
          '"start_date":"${b.formattedStartDate}","read_date":"${b.formattedReadDate ?? ""}"}');
      if (i < books.length - 1) buffer.writeln(',');
    }
    buffer.writeln();
    buffer.write(']');
    return buffer.toString();
  }

  String _toCsv(List<Book> books) {
    final buffer = StringBuffer();
    buffer.writeln('书名,作者,评分,阅读天数,读完日期');
    for (final b in books) {
      buffer.writeln(
          '${b.title},${b.author ?? ""},${b.rating ?? 0},${b.readingCycleDays ?? 0},${b.formattedReadDate ?? ""}');
    }
    return buffer.toString();
  }

  String _escape(String s) =>
      s.replaceAll('"', '\\"').replaceAll('\n', '\\n');
}
