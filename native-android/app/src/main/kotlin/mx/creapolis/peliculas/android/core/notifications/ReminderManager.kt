package mx.creapolis.peliculas.android.core.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import mx.creapolis.peliculas.android.MainActivity
import mx.creapolis.peliculas.android.R
import java.time.DayOfWeek
import java.time.Duration
import java.time.LocalDateTime
import java.time.temporal.TemporalAdjusters
import java.util.concurrent.TimeUnit

/**
 * Gestor de canales de notificación y recordatorios periódicos (port de `ReminderManager` en iOS).
 * - Viernes 19:00: Tendencias de la semana.
 * - Domingo 18:00: Recordatorio de Watchlist.
 */
class ReminderManager(private val context: Context) {

  private val prefs = context.getSharedPreferences("peliculas.reminders.v1", Context.MODE_PRIVATE)

  private val _enabled = kotlinx.coroutines.flow.MutableStateFlow(prefs.getBoolean(KEY_ENABLED, false))
  /** Desactivados por defecto (como iOS): se piden en contexto desde Cuenta. */
  val enabled: kotlinx.coroutines.flow.StateFlow<Boolean> = _enabled

  init {
    createChannels()
  }

  /** Activa/desactiva. El permiso POST_NOTIFICATIONS lo pide la UI antes de activar. */
  fun setEnabled(on: Boolean, watchlistCount: Int) {
    prefs.edit().putBoolean(KEY_ENABLED, on).apply()
    _enabled.value = on
    if (on) {
      reschedule(watchlistCount)
    } else {
      WorkManager.getInstance(context).apply {
        cancelUniqueWork(WORK_FRIDAY_TRENDS)
        cancelUniqueWork(WORK_SUNDAY_WATCHLIST)
      }
    }
  }

  fun createChannels() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

      val remindersChannel = NotificationChannel(
        CHANNEL_REMINDERS,
        context.getString(R.string.channel_reminders_name),
        NotificationManager.IMPORTANCE_DEFAULT,
      ).apply {
        description = context.getString(R.string.channel_reminders_desc)
      }

      val episodesChannel = NotificationChannel(
        CHANNEL_EPISODES,
        context.getString(R.string.channel_episodes_name),
        NotificationManager.IMPORTANCE_HIGH,
      ).apply {
        description = context.getString(R.string.channel_episodes_desc)
      }

      notificationManager.createNotificationChannels(listOf(remindersChannel, episodesChannel))
    }
  }

  /**
   * Programa o actualiza los recordatorios semanales (igual que iOS ReminderManager.reschedule).
   */
  fun reschedule(watchlistCount: Int) {
    if (!_enabled.value) return
    val workManager = WorkManager.getInstance(context)

    // Viernes 19:00: Tendencias
    val delayFriday = calculateDelayToNext(DayOfWeek.FRIDAY, 19, 0)
    val fridayWork = PeriodicWorkRequestBuilder<TrendingReminderWorker>(7, TimeUnit.DAYS)
      .setInitialDelay(delayFriday.toMillis(), TimeUnit.MILLISECONDS)
      .build()

    workManager.enqueueUniquePeriodicWork(
      WORK_FRIDAY_TRENDS,
      ExistingPeriodicWorkPolicy.UPDATE,
      fridayWork,
    )

    // Domingo 18:00: Watchlist (solo si hay elementos por ver)
    if (watchlistCount > 0) {
      val delaySunday = calculateDelayToNext(DayOfWeek.SUNDAY, 18, 0)
      val sundayWork = PeriodicWorkRequestBuilder<WatchlistReminderWorker>(7, TimeUnit.DAYS)
        .setInitialDelay(delaySunday.toMillis(), TimeUnit.MILLISECONDS)
        .setInputData(workDataOf(KEY_WATCHLIST_COUNT to watchlistCount))
        .build()

      workManager.enqueueUniquePeriodicWork(
        WORK_SUNDAY_WATCHLIST,
        ExistingPeriodicWorkPolicy.UPDATE,
        sundayWork,
      )
    } else {
      workManager.cancelUniqueWork(WORK_SUNDAY_WATCHLIST)
    }
  }

  companion object {
    const val CHANNEL_REMINDERS = "peliculas_reminders"
    const val CHANNEL_EPISODES = "peliculas_episodes"

    const val WORK_FRIDAY_TRENDS = "work_friday_trends"
    const val WORK_SUNDAY_WATCHLIST = "work_sunday_watchlist"
    const val KEY_WATCHLIST_COUNT = "watchlist_count"
    private const val KEY_ENABLED = "enabled"

    fun calculateDelayToNext(dayOfWeek: DayOfWeek, hour: Int, minute: Int, now: LocalDateTime = LocalDateTime.now()): Duration {
      var target = now.with(TemporalAdjusters.nextOrSame(dayOfWeek))
        .withHour(hour).withMinute(minute).withSecond(0).withNano(0)
      if (!target.isAfter(now)) {
        target = target.plusWeeks(1)
      }
      return Duration.between(now, target)
    }
  }
}

/** Worker para el recordatorio de tendencias de los viernes. */
class TrendingReminderWorker(
  private val context: Context,
  params: WorkerParameters,
) : CoroutineWorker(context, params) {

  override suspend fun doWork(): Result {
    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://peliculas.creapolis.dev/trending")).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      setClass(context, MainActivity::class.java)
    }
    val pendingIntent = PendingIntent.getActivity(
      context, 1001, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val notification = NotificationCompat.Builder(context, ReminderManager.CHANNEL_REMINDERS)
      .setSmallIcon(R.drawable.ic_stat_notification)
      .setContentTitle(context.getString(R.string.reminder_trends_title))
      .setContentText(context.getString(R.string.reminder_trends_body))
      .setAutoCancel(true)
      .setContentIntent(pendingIntent)
      .build()

    try {
      NotificationManagerCompat.from(context).notify(1001, notification)
    } catch (_: SecurityException) {
      // Permiso denegado por el usuario
    }
    return Result.success()
  }
}

/** Worker para el recordatorio dominical de Watchlist. */
class WatchlistReminderWorker(
  private val context: Context,
  params: WorkerParameters,
) : CoroutineWorker(context, params) {

  override suspend fun doWork(): Result {
    val count = inputData.getInt(ReminderManager.KEY_WATCHLIST_COUNT, 0)
    if (count <= 0) return Result.success()

    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://peliculas.creapolis.dev/library")).apply {
      flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
      setClass(context, MainActivity::class.java)
    }
    val pendingIntent = PendingIntent.getActivity(
      context, 1002, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )

    val notification = NotificationCompat.Builder(context, ReminderManager.CHANNEL_REMINDERS)
      .setSmallIcon(R.drawable.ic_stat_notification)
      .setContentTitle(context.getString(R.string.reminder_watchlist_title))
      .setContentText(context.getString(R.string.reminder_watchlist_body, count))
      .setAutoCancel(true)
      .setContentIntent(pendingIntent)
      .build()

    try {
      NotificationManagerCompat.from(context).notify(1002, notification)
    } catch (_: SecurityException) {
      // Permiso denegado
    }
    return Result.success()
  }
}
