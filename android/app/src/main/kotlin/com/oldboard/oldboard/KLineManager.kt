package com.oldboard.oldboard

import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import com.hoho.android.usbserial.driver.FtdiSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort
import com.hoho.android.usbserial.driver.UsbSerialProber
import java.io.IOException
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

sealed class KCmd {
    data class SetGroups(val groups: List<Int>) : KCmd()
    data class SwitchAddress(val address: Int, val groups: List<Int>) : KCmd()
    object ReadFaults : KCmd()
    object ClearFaults : KCmd()
    data class ThrottleAlign(val group: Int = 98) : KCmd()
    object ResetAdaptations : KCmd()
    object Disconnect : KCmd()
}

class CableDetachedException(msg: String) : Exception(msg)

/**
 * Gere le thread unique de communication K-Line (une seule session active a la fois)
 * et la reconnexion USB FTDI sans concurrence ni spam en cas de debranchement.
 */
class KLineManager(
    private val usb: UsbManager,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val lifecycleLock = Any()
    private val sessionId = AtomicInteger(0)
    private val active = AtomicBoolean(false)
    private val cmds = LinkedBlockingQueue<KCmd>()
    private var thread: Thread? = null

    private fun log(sid: Int, msg: String) {
        if (sessionId.get() == sid) emit(mapOf("type" to "log", "msg" to msg))
    }

    private fun state(sid: Int, s: String, msg: String? = null) {
        if (sessionId.get() == sid) emit(mapOf("type" to "state", "state" to s, "msg" to msg))
    }

    private fun emitForSession(sid: Int, payload: Map<String, Any?>) {
        if (sessionId.get() == sid) emit(payload)
    }

    private fun isAlive(sid: Int): Boolean =
        active.get() && sessionId.get() == sid && !Thread.currentThread().isInterrupted

    fun post(c: KCmd) { cmds.offer(c) }

    fun start(driver: UsbSerialDriver, address: Int, groups: List<Int>) {
        synchronized(lifecycleLock) {
            stopInternal()
            cmds.clear()
            val sid = sessionId.incrementAndGet()
            active.set(true)
            thread = Thread({ runLoop(sid, driver, address, groups) }, "kline-$sid").apply { start() }
        }
    }

    fun stop() {
        synchronized(lifecycleLock) {
            stopInternal()
        }
    }

    private fun stopInternal() {
        val old = thread
        active.set(false)
        sessionId.incrementAndGet()
        cmds.offer(KCmd.Disconnect)
        old?.interrupt()
        if (old != null && old !== Thread.currentThread()) {
            try { old.join(3500) } catch (_: InterruptedException) { }
        }
        thread = null
    }

    private fun isUsbHardwareError(e: Throwable): Boolean {
        if (e is IOException || e is CableDetachedException) return true
        val m = (e.message ?: "").lowercase()
        return m.contains("usb") ||
            m.contains("get_status") ||
            m.contains("baudrate") ||
            m.contains("break") ||
            m.contains("result=-1") ||
            m.contains("device") ||
            m.contains("connection") ||
            m.contains("closed") ||
            m.contains("pipe")
    }

    private fun sleepInterruptible(ms: Long) {
        try {
            Thread.sleep(ms)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }

    private fun runLoop(sid: Int, initialDriver: UsbSerialDriver, startAddr: Int, startGroups: List<Int>) {
        var address = startAddr
        var groups = startGroups
        var conn: UsbDeviceConnection? = null
        var port: UsbSerialPort? = null
        var lastErrorMsg: String? = null

        fun closeUsb() {
            try { port?.close() } catch (_: Exception) { }
            try { conn?.close() } catch (_: Exception) { }
            port = null
            conn = null
        }

        fun openUsb(): UsbSerialPort {
            closeUsb()
            state(sid, "connecting", "Ouverture du câble USB FTDI")
            val probed = UsbSerialProber.getDefaultProber().findAllDrivers(usb)
            if (probed.isEmpty()) {
                throw CableDetachedException("Câble USB débranché")
            }
            val activeDriver = probed.firstOrNull {
                it.device.vendorId == initialDriver.device.vendorId &&
                    it.device.productId == initialDriver.device.productId
            } ?: probed.first()

            if (!usb.hasPermission(activeDriver.device)) {
                throw CableDetachedException("Permission USB manquante ou câble débranché")
            }
            val c = usb.openDevice(activeDriver.device)
                ?: throw IOException("Impossible d'ouvrir le câble USB (openDevice=null)")
            conn = c
            val p = activeDriver.ports[0]
            p.open(c)
            p.setParameters(9600, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
            try { p.setDTR(true); p.setRTS(false) } catch (_: Exception) { }
            if (p is FtdiSerialDriver.FtdiSerialPort) {
                try {
                    p.setLatencyTimer(1)
                    log(sid, "FTDI : latence 1 ms")
                } catch (_: Exception) { }
            }
            try { p.purgeHwBuffers(true, true) } catch (_: Exception) { }
            log(sid, "Câble ouvert : ${activeDriver.javaClass.simpleName}")
            port = p
            return p
        }

        try {
            var attempt = 0
            while (isAlive(sid)) {
                var proto: Kwp1281? = null
                try {
                    val activePort = port ?: openUsb()
                    proto = Kwp1281(activePort) { log(sid, it) }

                    state(sid, "init", "Connexion calculateur 0x%02X".format(address))
                    val bauds = if (address == 0x01) listOf(9600, 10400) else listOf(10400, 9600)
                    val id = proto.connect(address, bauds)
                    if (!isAlive(sid)) break
                    emitForSession(sid, mapOf("type" to "connected", "address" to address, "ecuId" to id, "baud" to proto.baud))
                    state(sid, "connected", id)
                    attempt = 0
                    lastErrorMsg = null
                    var gi = 0

                    session@ while (isAlive(sid)) {
                        when (val c = cmds.poll()) {
                            is KCmd.SetGroups -> { groups = c.groups; gi = 0 }
                            is KCmd.SwitchAddress -> {
                                if (c.address == address) {
                                    // Deja connecte sur cette adresse : on met simplement a jour les groupes sans couper la session
                                    groups = c.groups
                                    gi = 0
                                } else {
                                    proto.end()
                                    address = c.address
                                    groups = c.groups
                                    // Vide tout éventuel SwitchAddress en doublon dans la file
                                    cmds.removeAll { it is KCmd.SwitchAddress && it.address == address }
                                    sleepInterruptible(2600)
                                    break@session
                                }
                            }
                            is KCmd.ReadFaults -> {
                                val f = proto.readFaults()
                                emitForSession(sid, mapOf("type" to "faults", "address" to address, "codes" to f))
                            }
                            is KCmd.ClearFaults -> {
                                val f = proto.clearFaults()
                                emitForSession(sid, mapOf("type" to "faults", "address" to address, "codes" to f))
                                emitForSession(
                                    sid,
                                    mapOf(
                                        "type" to "serviceDone",
                                        "action" to "clearFaults",
                                        "ok" to true,
                                        "msg" to "Codes défaut moteur effacés ✔",
                                    )
                                )
                            }
                            is KCmd.ResetAdaptations -> {
                                val ok = proto.resetAdaptations()
                                emitForSession(
                                    sid,
                                    mapOf(
                                        "type" to "serviceDone",
                                        "action" to "resetAdaptations",
                                        "ok" to ok,
                                        "msg" to if (ok) "Auto-adaptations moteur remises à zéro ✔" else "Réponse inattendue du calculateur",
                                    )
                                )
                            }
                            is KCmd.ThrottleAlign -> {
                                var targetGroup = c.group
                                log(sid, "Alignement boîtier papillon (Groupe %03d en Réglage de base 0x28) pendant ~12 s...".format(targetGroup))
                                emitForSession(sid, mapOf("type" to "throttleProgress", "step" to 0, "total" to 20, "msg" to "Entrée en Réglage de base Groupe %03d...".format(targetGroup)))
                                var lastVals = proto.startBasicSetting(targetGroup)
                                if (lastVals == null) {
                                    val fallback = if (targetGroup == 98) 60 else 98
                                    log(sid, "Groupe %03d refusé, essai du Réglage de base sur Groupe %03d...".format(targetGroup, fallback))
                                    targetGroup = fallback
                                    lastVals = proto.startBasicSetting(targetGroup)
                                }
                                if (lastVals != null) {
                                    emitForSession(
                                        sid,
                                        mapOf(
                                            "type" to "throttleProgress",
                                            "step" to 1,
                                            "total" to 20,
                                            "values" to lastVals,
                                            "msg" to "Calibrage butées papillon (1/20)...",
                                        )
                                    )
                                    for (step in 2..20) {
                                        if (!isAlive(sid)) break
                                        sleepInterruptible(500)
                                        val v = proto.pollBasicSetting(targetGroup)
                                        if (v != null) lastVals = v
                                        emitForSession(
                                            sid,
                                            mapOf(
                                                "type" to "throttleProgress",
                                                "step" to step,
                                                "total" to 20,
                                                "values" to (lastVals ?: emptyList<Map<String, Int>>()),
                                                "msg" to "Calibrage butées papillon ($step/20)...",
                                            )
                                        )
                                    }
                                }
                                // Sortie du mode Reglage de base par retour en lecture normale (0x29)
                                try { proto.readGroup(1) } catch (_: Exception) { }
                                emitForSession(
                                    sid,
                                    mapOf(
                                        "type" to "serviceDone",
                                        "action" to "throttleAlign",
                                        "ok" to (lastVals != null),
                                        "msg" to if (lastVals != null) "Calibrage du boîtier papillon (Groupe %03d) terminé ✔".format(targetGroup) else "Échec entrée en Réglage de base (vérifier contact mis / moteur coupé)",
                                    )
                                )
                            }
                            is KCmd.Disconnect -> { proto.end(); active.set(false); break@session }
                            null -> { }
                        }
                        if (!isAlive(sid)) break
                        if (groups.isEmpty()) {
                            proto.keepAlive()
                            sleepInterruptible(80)
                        } else {
                            val g = groups[gi % groups.size]
                            gi++
                            try {
                                val res = proto.readGroup(g)
                                emitForSession(
                                    sid,
                                    mapOf(
                                        "type" to "group",
                                        "address" to address,
                                        "group" to g,
                                        "ok" to res.ok,
                                        "values" to res.values,
                                        "isRawF4" to res.isRawF4,
                                        "rawBytes" to res.rawBytes,
                                        "rawTx" to res.rawTxHex,
                                        "rawRx" to res.rawRxHex,
                                        "error" to res.error,
                                    )
                                )
                            } catch (ge: Exception) {
                                if (!isAlive(sid)) break
                                val txHex = proto.lastTxHex()
                                val rxHex = proto.lastRxHex()
                                log(sid, "Erreur lecture groupe %03d : %s | TX=[%s] RX=[%s]".format(g, ge.message, txHex, rxHex))
                                emitForSession(
                                    sid,
                                    mapOf(
                                        "type" to "group",
                                        "address" to address,
                                        "group" to g,
                                        "ok" to false,
                                        "values" to emptyList<Map<String, Int>>(),
                                        "isRawF4" to false,
                                        "rawBytes" to emptyList<Int>(),
                                        "rawTx" to txHex,
                                        "rawRx" to rxHex,
                                        "error" to (ge.message ?: ge.javaClass.simpleName),
                                    )
                                )
                                if (isUsbHardwareError(ge)) {
                                    throw ge
                                }
                                try {
                                    sleepInterruptible(60)
                                    proto.purgeRx()
                                    proto.keepAlive()
                                    log(sid, "Session KWP1281 resynchronisée après échec du groupe %03d".format(g))
                                } catch (re: Exception) {
                                    log(sid, "Resynchronisation impossible (${re.message}), réinitialisation 5 bauds...")
                                    throw ge
                                }
                            }
                        }
                    }
                } catch (e: InterruptedException) {
                    break
                } catch (e: CableDetachedException) {
                    // Cable physiquement debranche ou permission absente : on arrete proprement sans boucler
                    closeUsb()
                    if (isAlive(sid)) {
                        log(sid, "${e.message} -> arrêt de la session (en attente de branchement USB)")
                        active.set(false)
                        state(sid, "disconnected", e.message)
                    }
                    break
                } catch (e: Exception) {
                    if (!isAlive(sid)) break
                    attempt++
                    val errMsg = e.message ?: e.javaClass.simpleName
                    val usbErr = isUsbHardwareError(e)

                    if (errMsg != lastErrorMsg) {
                        state(sid, "error", errMsg)
                        lastErrorMsg = errMsg
                    }

                    while (true) {
                        when (val c = cmds.poll() ?: break) {
                            is KCmd.SetGroups -> groups = c.groups
                            is KCmd.SwitchAddress -> { address = c.address; groups = c.groups }
                            is KCmd.Disconnect -> active.set(false)
                            else -> { }
                        }
                    }

                    if (!isAlive(sid)) break

                    if (usbErr) {
                        closeUsb()
                        // Si le cable n'est plus present sur le bus USB apres 2 verifications, on passe en disconnected sans spammer
                        val stillPresent = try {
                            UsbSerialProber.getDefaultProber().findAllDrivers(usb).isNotEmpty()
                        } catch (_: Exception) {
                            false
                        }
                        if (!stillPresent && attempt >= 2) {
                            log(sid, "Câble USB débranché -> passage en état déconnecté")
                            active.set(false)
                            state(sid, "disconnected", "Câble USB débranché")
                            break
                        }
                        val waitMs = if (attempt <= 2) 1500L else 5000L
                        if (attempt <= 2) {
                            log(sid, "Micro-coupure USB ($errMsg) -> réouverture du port FTDI dans ${waitMs} ms")
                        }
                        sleepInterruptible(waitMs)
                    } else {
                        sleepInterruptible(if (attempt < 3) 2800L else 5000L)
                    }
                }
            }
        } catch (e: Exception) {
            if (isAlive(sid)) state(sid, "error", e.message ?: e.javaClass.simpleName)
        } finally {
            closeUsb()
            if (sessionId.get() == sid) {
                active.set(false)
                state(sid, "disconnected", null)
            }
        }
    }
}
