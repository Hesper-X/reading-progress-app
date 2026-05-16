/// 年度目标数据模型（V3.0 新增）
class YearGoal {
  final int year;
  int target;
  bool isSetByUser;

  YearGoal({
    required this.year,
    this.target = 52,
    this.isSetByUser = false,
  });

  factory YearGoal.fromMap(Map<String, dynamic> map) {
    return YearGoal(
      year: map['year'] as int,
      target: map['target'] as int? ?? 52,
      isSetByUser: (map['is_set_by_user'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'year': year,
        'target': target,
        'is_set_by_user': isSetByUser ? 1 : 0,
      };

  @override
  String toString() => 'YearGoal(year: $year, target: $target, setByUser: $isSetByUser)';
}
