package mx.creapolis.peliculas

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.Log

class FirebaseMessagingService : FirebaseMessagingService() {

    companion object {
        private const val TAG = "FCMService"
        private const val CHANNEL_ID = "peliculas_notifications"
        private const val CHANNEL_NAME = "Peliculas Notifications"
        private const val CHANNEL_DESCRIPTION = "Notificaciones de la app Peliculas"
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "From: ${remoteMessage.from}")

        // Verificar si el mensaje contiene datos
        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "Message data payload: ${remoteMessage.data}")
            handleDataMessage(remoteMessage.data)
        }

        // Verificar si el mensaje contiene una notificación
        remoteMessage.notification?.let {
            Log.d(TAG, "Message Notification Body: ${it.body}")
            showNotification(it.title, it.body, remoteMessage.data)
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "Refreshed token: $token")
        
        // Enviar el token al servidor de la aplicación
        sendRegistrationToServer(token)
    }

    private fun handleDataMessage(data: Map<String, String>) {
        // Manejar mensajes de datos personalizados
        val notificationType = data["type"]
        val title = data["title"]
        val body = data["body"]
        val actionUrl = data["actionUrl"]
        
        when (notificationType) {
            "new_movie" -> {
                showNotification(
                    title ?: "Nueva Película",
                    body ?: "Hay una nueva película disponible",
                    data
                )
            }
            "recommendation" -> {
                showNotification(
                    title ?: "Recomendación",
                    body ?: "Tenemos una recomendación para ti",
                    data
                )
            }
            "list_update" -> {
                showNotification(
                    title ?: "Lista Actualizada",
                    body ?: "Una de tus listas ha sido actualizada",
                    data
                )
            }
            else -> {
                showNotification(
                    title ?: "Notificación",
                    body ?: "Tienes una nueva notificación",
                    data
                )
            }
        }
    }

    private fun showNotification(title: String?, body: String?, data: Map<String, String>) {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            // Agregar datos extras si es necesario
            data.forEach { (key, value) ->
                putExtra(key, value)
            }
        }

        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.launcher_icon)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setSound(android.provider.Settings.System.DEFAULT_NOTIFICATION_URI)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Generar un ID único para cada notificación
        val notificationId = System.currentTimeMillis().toInt()
        notificationManager.notify(notificationId, notificationBuilder.build())
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = CHANNEL_DESCRIPTION
                enableLights(true)
                enableVibration(true)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun sendRegistrationToServer(token: String) {
        // Aquí se enviaría el token al servidor de la aplicación
        // Por ahora solo lo registramos en los logs
        Log.d(TAG, "Token sent to server: $token")
        
        // TODO: Implementar envío del token al backend
        // Esto se puede hacer a través de una llamada HTTP al servidor
        // o guardando el token localmente para enviarlo cuando la app esté activa
    }
}