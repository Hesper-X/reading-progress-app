/// 表单验证工具
class Validators {
  Validators._();

  /// 验证书名（必填，1-100 字符）
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入书名';
    }
    if (value.trim().length > 100) {
      return '书名不超过100字';
    }
    return null;
  }

  /// 验证作者（可选，0-50 字符）
  static String? validateAuthor(String? value) {
    if (value != null && value.trim().length > 50) {
      return '作者不超过50字';
    }
    return null;
  }

  /// 验证感想（可选，0-200 字符）
  static String? validateNotes(String? value) {
    if (value != null && value.trim().length > 200) {
      return '感想不超过200字';
    }
    return null;
  }

  /// 验证评分
  static String? validateRating(int? rating) {
    if (rating == null || rating < 1 || rating > 5) {
      return '请评分';
    }
    return null;
  }

  /// 验证日期
  static String? validateDate(DateTime? date) {
    if (date == null) {
      return '请选择日期';
    }
    return null;
  }
}
