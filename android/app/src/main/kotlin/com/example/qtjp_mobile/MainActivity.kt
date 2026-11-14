package com.example.qtjp_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var permissionResult: MethodChannel.Result? = null
    private val manager get() = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
    private val preferences get() = getSharedPreferences("qtjp_notifications", MODE_PRIVATE)
    private val channelId = "qtjp_learning"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(channelId, "Thông báo QTJP Learning", NotificationManager.IMPORTANCE_DEFAULT))
        }
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "qtjp/device_notifications")
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "status" -> result.success(notificationStatus())
                "request" -> {
                    if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionResult != null) {
                            result.error("BUSY", "Đang yêu cầu quyền thông báo.", null)
                        } else {
                            permissionResult = result
                            preferences.edit().putBoolean("asked", true).apply()
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 6051)
                        }
                    } else result.success(notificationStatus())
                }
                "settings" -> {
                    val settings = if (Build.VERSION.SDK_INT >= 26) Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    startActivity(settings)
                    result.success(null)
                }
                "show" -> {
                    if (notificationStatus() == "enabled") {
                        val id = call.argument<Number>("id")?.toInt() ?: 0
                        val open = Intent(this, MainActivity::class.java).putExtra("qtjp_notification", true).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                        val pending = PendingIntent.getActivity(this, id, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channelId) else Notification.Builder(this)
                        builder.setSmallIcon(R.drawable.ic_qtjp_notification)
                            .setContentTitle((call.argument<String>("title") ?: "QTJP Learning").take(160))
                            .setContentText((call.argument<String>("body") ?: "").take(500))
                            .setContentIntent(pending).setAutoCancel(true)
                            .setVisibility(Notification.VISIBILITY_PRIVATE)
                        manager.notify("qtjp_account", id, builder.build())
                    }
                    result.success(null)
                }
                "clear" -> { manager.cancelAll(); result.success(null) }
                "consumeTap" -> {
                    val opened = intent?.getBooleanExtra("qtjp_notification", false) == true
                    intent?.removeExtra("qtjp_notification")
                    result.success(opened)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun notificationStatus(): String {
        val granted = Build.VERSION.SDK_INT < 33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        if (!granted) return if (preferences.getBoolean("asked", false)) "denied" else "notDetermined"
        if (Build.VERSION.SDK_INT >= 24 && !manager.areNotificationsEnabled()) return "denied"
        if (Build.VERSION.SDK_INT >= 26 && manager.getNotificationChannel(channelId)?.importance == NotificationManager.IMPORTANCE_NONE) return "denied"
        return "enabled"
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 6051) {
            permissionResult?.success(notificationStatus())
            permissionResult = null
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("qtjp_notification", false)) {
            intent.removeExtra("qtjp_notification")
            channel?.invokeMethod("opened", null)
        }
    }
}
