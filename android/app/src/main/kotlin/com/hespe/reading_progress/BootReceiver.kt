package com.hespe.reading_progress

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build

/**
 * 开机广播接收器
 *
 * 设备开机后自动从 SharedPreferences 读取提醒设置和时间，
 * 通过 AlarmManager 重新注册每日提醒。
 *
 * 到点时直接弹出系统通知，无需 App 前台运行。
 *
 * 文案逻辑：
 * - 首次启动（Flutter 未初始化）使用通用文案
 * - 后续每天到点弹出通知，用户点击后打开 App
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val PREFS_FILE = "FlutterSharedPreferences"
        private const val KEY_REMINDER_ENABLED = "flutter.daily_reminder"
        private const val KEY_REMINDER_TIME = "flutter.reminder_time"
        private const val REQUEST_CODE_ALARM = 1001
        private const val REQUEST_CODE_NOTIFY = 1002
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "daily_reading_reminder"
        private const val ACTION_REMINDER = "com.hespe.reading_progress.DAILY_REMINDER"
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> onBootCompleted(context)
            ACTION_REMINDER -> onAlarmTriggered(context)
        }
    }

    /**
     * 开机后恢复提醒调度
     */
    private fun onBootCompleted(context: Context) {
        android.util.Log.d("BootReceiver", "设备开机，检查提醒设置")

        val prefs = getPrefs(context)
        val reminderEnabled = prefs.getBoolean(KEY_REMINDER_ENABLED, false)
        val reminderTime = prefs.getString(KEY_REMINDER_TIME, "21:00") ?: "21:00"

        if (!reminderEnabled) {
            android.util.Log.d("BootReceiver", "提醒已关闭，跳过恢复")
            return
        }

        val (hour, minute) = parseTime(reminderTime)
        val triggerTime = computeNextTrigger(hour, minute)

        scheduleAlarm(context, triggerTime)

        android.util.Log.d("BootReceiver",
            "提醒已恢复：每天 $reminderTime，下次触发：${formatTime(triggerTime)}")
    }

    /**
     * 提醒时间触发 → 弹出系统通知
     */
    private fun onAlarmTriggered(context: Context) {
        android.util.Log.d("BootReceiver", "每日提醒触发")

        ensureNotificationChannel(context)

        val prefs = getPrefs(context)
        val reminderEnabled = prefs.getBoolean(KEY_REMINDER_ENABLED, false)

        if (!reminderEnabled) return

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context, REQUEST_CODE_NOTIFY, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            android.app.Notification.Builder(context, CHANNEL_ID)
        } else {
            android.app.Notification.Builder(context)
        }.apply {
            setContentTitle("阅读提醒")
            setContentText("今天读书了吗？")
            setSmallIcon(android.R.drawable.ic_dialog_info)
            setAutoCancel(true)
            setContentIntent(pendingIntent)
            setDefaults(android.app.Notification.DEFAULT_ALL)
        }

        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(NOTIFICATION_ID, notification.build())

        // 安排明天的提醒
        val (hour, minute) = parseTime(
            prefs.getString(KEY_REMINDER_TIME, "21:00") ?: "21:00"
        )
        val nextTrigger = computeNextTrigger(hour, minute)
        scheduleAlarm(context, nextTrigger)
    }

    /**
     * 通过 AlarmManager 调度下一次提醒
     */
    private fun scheduleAlarm(context: Context, triggerTime: Long) {
        val intent = Intent(context, BootReceiver::class.java).apply {
            action = ACTION_REMINDER
        }

        val pendingIntent = PendingIntent.getBroadcast(
            context, REQUEST_CODE_ALARM, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.RTC_WAKEUP, triggerTime, pendingIntent
            )
        }
    }

    /**
     * 创建通知渠道（Android 8.0+ 必需）
     */
    private fun ensureNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "每日阅读提醒",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "提醒你阅读在读书籍"
                enableVibration(true)
                setSound(null, null) // 使用默认通知声音
            }
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun getPrefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)

    private fun parseTime(time: String): Pair<Int, Int> {
        val parts = time.split(":")
        return Pair(parts[0].toIntOrNull() ?: 21, parts[1].toIntOrNull() ?: 0)
    }

    private fun computeNextTrigger(hour: Int, minute: Int): Long {
        val calendar = java.util.Calendar.getInstance()
        calendar.set(java.util.Calendar.HOUR_OF_DAY, hour)
        calendar.set(java.util.Calendar.MINUTE, minute)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)

        val now = System.currentTimeMillis()
        if (calendar.timeInMillis <= now) {
            calendar.add(java.util.Calendar.DAY_OF_MONTH, 1)
        }

        return calendar.timeInMillis
    }

    private fun formatTime(millis: Long): String {
        val sdf = java.text.SimpleDateFormat("MM-dd HH:mm", java.util.Locale.getDefault())
        return sdf.format(java.util.Date(millis))
    }
}
