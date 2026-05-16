import 'package:flutter_test/flutter_test.dart';
import 'package:reading_progress/utils/validators.dart';
import 'package:reading_progress/utils/date_utils.dart';

void main() {
  group('Validators', () {
    test('validateTitle returns null for valid title', () {
      expect(Validators.validateTitle('活着'), isNull);
      expect(Validators.validateTitle('百年孤独'), isNull);
    });

    test('validateTitle returns error for empty', () {
      expect(Validators.validateTitle(''), isNotNull);
      expect(Validators.validateTitle(null), isNotNull);
      expect(Validators.validateTitle('   '), isNotNull);
    });

    test('validateTitle returns error for too long', () {
      final long = String.fromCharCodes(List.filled(101, 65));
      expect(Validators.validateTitle(long), isNotNull);
    });

    test('validateAuthor returns null for valid author', () {
      expect(Validators.validateAuthor('余华'), isNull);
      expect(Validators.validateAuthor(null), isNull);
      expect(Validators.validateAuthor(''), isNull);
    });

    test('validateNotes returns null for valid notes', () {
      expect(Validators.validateNotes('好书'), isNull);
      expect(Validators.validateNotes(null), isNull);
    });

    test('validateNotes returns error for too long', () {
      final long = String.fromCharCodes(List.filled(201, 65));
      expect(Validators.validateNotes(long), isNotNull);
    });

    test('validateRating returns null for valid rating', () {
      expect(Validators.validateRating(3), isNull);
      expect(Validators.validateRating(5), isNull);
      expect(Validators.validateRating(1), isNull);
    });

    test('validateRating returns error for invalid rating', () {
      expect(Validators.validateRating(null), isNotNull);
      expect(Validators.validateRating(0), isNotNull);
      expect(Validators.validateRating(6), isNotNull);
    });

    test('validateDate returns error for null date', () {
      expect(Validators.validateDate(null), isNotNull);
    });
  });

  group('DateUtils', () {
    test('formatChinese returns correct format', () {
      final date = DateTime(2026, 5, 8);
      expect(DateUtils.formatChinese(date), '2026年5月8日');
    });

    test('formatIso returns correct format', () {
      final date = DateTime(2026, 5, 8);
      expect(DateUtils.formatIso(date), '2026-05-08');
    });

    test('elapsedDays returns correct difference', () {
      final start = DateTime.now().subtract(const Duration(days: 5));
      expect(DateUtils.elapsedDays(start), 5);
    });

    test('readingCycleDays returns correct cycle', () {
      expect(DateUtils.readingCycleDays(
        DateTime(2026, 4, 1),
        DateTime(2026, 5, 8),
      ), 37);
    });
  });
}
