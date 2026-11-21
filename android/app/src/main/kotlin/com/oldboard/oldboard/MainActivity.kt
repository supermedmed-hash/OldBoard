package com.oldboard.oldboard

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialProber
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    private val actionPermission = "com.oldboard.oldboard.USB_PERMISSION"
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var updateSink: EventChannel.EventSink? = null
    private lateinit var usb: UsbManager
    private lateinit var manager: KLineManager
    private var pending: Triple<UsbSerialDriver, Int, List<Int>>? = null

    private fun emit(ev: Map<String, Any?>) {
        main.post { sink?.success(ev) }
    }

    private fun emitUpdate(ev: Map<String, Any?>) {
        main.post { updateSink?.success(ev) }
    }

    private fun getInstalledVersion(): String {
        return try {
            val info = if (Build.VERSION.SDK_INT >= 33) {
                packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(0))
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(packageName, 0)
            }
            info.versionName ?: "1.0.0"
        } catch (_: Exception) {
            "1.0.0"
        }
    }

    private fun downloadAndInstallApk(apkUrl: String) {
        Thread {
            var conn: HttpURLConnection? = null
            try {
                var currentUrl = apkUrl
                var hops = 0
                while (hops < 8) {
                    val c = (URL(currentUrl).openConnection() as HttpURLConnection).apply {
                        instanceFollowRedirects = false
                        connectTimeout = 15000
                        readTimeout = 30000
                        setRequestProperty("User-Agent", "OldBoard-Android")
                    }
                    val code = c.responseCode
                    if (code in 300..399) {
                        val loc = c.getHeaderField("Location")
                        c.disconnect()
                        if (loc.isNullOrBlank()) throw IllegalStateException("Redirection invalide ($code)")
                        currentUrl = URL(URL(currentUrl), loc).toString()
                        hops++
                    } else {
                        conn = c
                        break
                    }
                }
                val activeConn = conn ?: throw IllegalStateException("Trop de redirections")
                if (activeConn.responseCode !in 200..299) {
                    throw IllegalStateException("Erreur HTTP ${activeConn.responseCode}")
                }

                val total = activeConn.contentLengthLong
                val dir = File(cacheDir, "updates").apply { mkdirs() }
                val outFile = File(dir, "OldBoard-update.apk")
                if (outFile.exists()) outFile.delete()

                var received = 0L
                var lastEmit = 0L
                val buf = ByteArray(16 * 1024)
                activeConn.inputStream.use { input ->
                    FileOutputStream(outFile).use { output ->
                        while (true) {
                            val n = input.read(buf)
                            if (n <= 0) break
                            output.write(buf, 0, n)
                            received += n
                            val now = System.currentTimeMillis()
                            if (now - lastEmit >= 120) {
                                lastEmit = now
                                val progress = if (total > 0) (received.toDouble() / total.toDouble()).coerceIn(0.0, 1.0) else -1.0
                                emitUpdate(mapOf("state" to "downloading", "progress" to progress, "received" to received, "total" to total))
                            }
                        }
                    }
                }

                emitUpdate(mapOf("state" to "installing", "progress" to 1.0, "received" to received, "total" to total))
                main.post {
                    try {
                        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", outFile)
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(intent)
                        emitUpdate(mapOf("state" to "done"))
                    } catch (e: Exception) {
                        emitUpdate(mapOf("state" to "error", "msg" to (e.message ?: "Impossible de lancer l'installeur Android")))
                    }
                }
            } catch (e: Exception) {
                emitUpdate(mapOf("state" to "error", "msg" to (e.message ?: "Échec du téléchargement")))
            } finally {
                try { conn?.disconnect() } catch (_: Exception) { }
            }
        }.start()
    }

    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != actionPermission) return
            val p = pending ?: return
            pending = null
            if (usb.hasPermission(p.first.device)) {
                manager.start(p.first, p.second, p.third)
            } else {
                emit(mapOf("type" to "state", "state" to "error", "msg" to "Permission USB refusee"))
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        usb = getSystemService(Context.USB_SERVICE) as UsbManager
        manager = KLineManager(usb) { emit(it) }

        val filter = IntentFilter(actionPermission)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(receiver, filter)
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "oldboard/kline/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) { sink = events }
                override fun onCancel(arguments: Any?) { sink = null }
            })

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "oldboard/updater/progress")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) { updateSink = events }
                override fun onCancel(arguments: Any?) { updateSink = null }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oldboard/updater")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "getAppVersion" -> result.success(getInstalledVersion())
                        "downloadAndInstall" -> {
                            val url = call.argument<String>("url")
                            if (url.isNullOrBlank()) {
                                result.error("UPDATER", "URL APK manquante", null)
                            } else {
                                downloadAndInstallApk(url)
                                result.success(true)
                            }
                        }
                        "openUrl" -> {
                            val url = call.argument<String>("url")
                            if (!url.isNullOrBlank()) {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                            }
                            result.success(true)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("UPDATER", e.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oldboard/kline")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "listDevices" -> {
                            val list = UsbSerialProber.getDefaultProber().findAllDrivers(usb).map {
                                mapOf(
                                    "name" to (it.device.productName ?: it.device.deviceName),
                                    "driver" to it.javaClass.simpleName,
                                    "vendorId" to it.device.vendorId,
                                    "productId" to it.device.productId,
                                )
                            }
                            result.success(list)
                        }
                        "connect" -> {
                            val address = call.argument<Int>("address") ?: 0x01
                            val groups = call.argument<List<Int>>("groups") ?: emptyList()
                            val drivers = UsbSerialProber.getDefaultProber().findAllDrivers(usb)
                            if (drivers.isEmpty()) {
                                result.success(false)
                                emit(mapOf("type" to "state", "state" to "error", "msg" to "Aucun cable USB detecte"))
                            } else {
                                val d = drivers[0]
                                if (usb.hasPermission(d.device)) {
                                    manager.start(d, address, groups)
                                } else {
                                    pending = Triple(d, address, groups)
                                    val intent = Intent(actionPermission).setPackage(packageName)
                                    val flags = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
                                    usb.requestPermission(d.device, PendingIntent.getBroadcast(this, 0, intent, flags))
                                }
                                result.success(true)
                            }
                        }
                        "setGroups" -> {
                            manager.post(KCmd.SetGroups(call.argument<List<Int>>("groups") ?: emptyList()))
                            result.success(null)
                        }
                        "switchAddress" -> {
                            manager.post(
                                KCmd.SwitchAddress(
                                    call.argument<Int>("address") ?: 0x01,
                                    call.argument<List<Int>>("groups") ?: emptyList(),
                                )
                            )
                            result.success(null)
                        }
                        "readFaults" -> { manager.post(KCmd.ReadFaults); result.success(null) }
                        "clearFaults" -> { manager.post(KCmd.ClearFaults); result.success(null) }
                        "throttleAlign" -> {
                            val g = call.argument<Int>("group") ?: 98
                            manager.post(KCmd.ThrottleAlign(g))
                            result.success(null)
                        }
                        "resetAdaptations" -> { manager.post(KCmd.ResetAdaptations); result.success(null) }
                        "disconnect" -> { Thread { manager.stop() }.start(); result.success(null) }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("KLINE", e.message, null)
                }
            }
    }

    override fun onDestroy() {
        try { unregisterReceiver(receiver) } catch (_: Exception) { }
        Thread { manager.stop() }.start()
        super.onDestroy()
    }
}
