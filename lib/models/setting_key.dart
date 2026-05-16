/// 设置项键名枚举
enum SettingKey {
  yearlyGoal('yearly_goal', '0'),
  theme('theme', 'light'),
  dailyReminder('daily_reminder', 'false'),
  reminderTime('reminder_time', '21:00'),
  proPurchased('pro_purchased', 'false'),
  backupEnabled('backup_enabled', 'false');

  final String key;
  final String defaultValue;

  const SettingKey(this.key, this.defaultValue);
}
