package com.oldboard.oldboard

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialProber
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val actionPermission = "com.oldboard.oldboard.USB_PERMISSION"
    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private lateinit var usb: UsbManager
    private lateinit var manager: KLineManager
    private var pending: Triple<UsbSerialDriver, Int, List<Int>>? = null

    private fun emit(ev: Map<String, Any?>) {
        main.post { sink?.success(ev) }
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
