import 'package:flutter_test/flutter_test.dart';
import 'package:reading_progress/models/book.dart';

void main() {
  group('BookStatus', () {
    test('fromString reading', () {
      expect(BookStatus.fromString('reading'), BookStatus.reading);
    });

    test('fromString finished', () {
      expect(BookStatus.fromString('finished'), BookStatus.finished);
    });

    test('fromString abandoned', () {
      expect(BookStatus.fromString('abandoned'), BookStatus.abandoned);
    });

    test('fromString defaults to reading for unknown value', () {
      expect(BookStatus.fromString('unknown'), BookStatus.reading);
    });

    test('value returns correct string', () {
      expect(BookStatus.reading.value, 'reading');
      expect(BookStatus.finished.value, 'finished');
      expect(BookStatus.abandoned.value, 'abandoned');
    });
  });

  group('Book', () {
    final now = DateTime(2026, 5, 8);

    test('fromMap creates Book correctly', () {
      final map = {
        'id': 1,
        'title': '活着',
        'author': '余华',
        'cover_path': '/path/to/cover.jpg',
        'rating': 5,
        'notes': '很感动',
        'read_date': '2026-05-08',
        'start_date': '2026-04-01',
        'status': 'finished',
        'created_at': '2026-04-01T10:00:00',
      };

      final book = Book.fromMap(map);

      expect(book.id, 1);
      expect(book.title, '活着');
      expect(book.author, '余华');
      expect(book.rating, 5);
      expect(book.notes, '很感动');
      expect(book.status, BookStatus.finished);
      expect(book.readDate!.year, 2026);
      expect(book.startDate.year, 2026);
    });

    test('toMap produces correct Map', () {
      final book = Book(
        id: 1,
        title: '百年孤独',
        author: '马尔克斯',
        rating: 4,
        startDate: now,
        readDate: now,
        status: BookStatus.finished,
      );

      final map = book.toMap();

      expect(map['id'], 1);
      expect(map['title'], '百年孤独');
      expect(map['author'], '马尔克斯');
      expect(map['rating'], 4);
      expect(map['status'], 'finished');
      expect(map['start_date'], '2026-05-08');
      expect(map['read_date'], '2026-05-08');
    });

    test('elapsedDays returns correct days', () {
      final startDate = DateTime.now().subtract(const Duration(days: 8));
      final book = Book(title: '测试', startDate: startDate, status: BookStatus.reading);
      expect(book.elapsedDays, 8);
    });

    test('readingCycleDays returns correct days', () {
      final start = DateTime(2026, 4, 1);
      final end = DateTime(2026, 5, 8);
      final book = Book(
        title: '测试',
        startDate: start,
        readDate: end,
        status: BookStatus.finished,
      );
      expect(book.readingCycleDays, 37);
    });

    test('readingCycleDays returns null when readDate is null', () {
      final book = Book(
        title: '测试',
        startDate: DateTime(2026, 4, 1),
        status: BookStatus.reading,
      );
      expect(book.readingCycleDays, isNull);
    });

    test('copyWith creates modified copy', () {
      final book = Book(
        id: 1,
        title: '原版',
        startDate: DateTime(2026, 1, 1),
      );

      final copy = book.copyWith(title: '修改版', rating: 5);

      expect(copy.id, 1);
      expect(copy.title, '修改版');
      expect(copy.rating, 5);
      expect(copy.startDate, DateTime(2026, 1, 1));
    });

    test('formattedStartDate returns Chinese format', () {
      final book = Book(
        title: '测试',
        startDate: DateTime(2026, 5, 8),
      );
      expect(book.formattedStartDate, '2026年5月8日');
    });

    test('serialization roundtrip', () {
      final original = Book(
        id: 1,
        title: '活着',
        author: '余华',
        rating: 5,
        notes: '好书',
        startDate: DateTime(2026, 4, 1),
        readDate: DateTime(2026, 5, 8),
        status: BookStatus.finished,
        finishedAt: DateTime(2026, 5, 8, 10, 30),
      );

      final map = original.toMap();
      final restored = Book.fromMap(map);

      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.author, original.author);
      expect(restored.rating, original.rating);
      expect(restored.notes, original.notes);
      expect(restored.status, original.status);
    });
  });
}
