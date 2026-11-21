package com.oldboard.oldboard

import com.hoho.android.usbserial.driver.UsbSerialPort
import java.io.IOException

class KLineException(msg: String) : Exception(msg)

/**
 * Implementation du protocole VAG KWP1281 sur ligne K (cable KKL 409.1 FTDI).
 *
 * Commandes lecture :
 *  - 0x09 ACK (maintien de la session)
 *  - 0x29 lecture d'un bloc de mesures
 *  - 0x07 lecture des codes defaut
 *  - 0x06 fin de communication
 * Commandes atelier moteur (uniquement sur action explicite avec confirmation) :
 *  - 0x05 effacement des codes defaut (Clear DTC)
 *  - 0x28 reglage de base d'un groupe (ex: groupe 098 alignement boitier papillon J338)
 *  - 0x2A remise a zero des valeurs d'auto-adaptation (canal 00)
 */
class Kwp1281(private val port: UsbSerialPort, private val log: (String) -> Unit) {

    data class Block(val title: Int, val data: IntArray)

    data class GroupResult(
        val ok: Boolean,
        val values: List<Map<String, Int>>,
        val isRawF4: Boolean = false,
        val rawBytes: List<Int> = emptyList(),
        val rawTxHex: String = "",
        val rawRxHex: String = "",
        val error: String? = null,
    )

    private val buf = ByteArray(256)
    private val rx = ArrayDeque<Int>()
    private val txTrace = ArrayList<Int>()
    private val rxTrace = ArrayList<Int>()
    private var counter = 0
    private var echo = true
    var baud = 9600
        private set

    companion object {
        const val INTERBYTE_MS = 5L
        const val INTERBLOCK_MS = 12L
        const val T_FIRST_BYTE = 1500
        const val T_GROUP_RESPONSE = 1200
        const val T_BYTE = 1000
    }

    // ---------------------------------------------------------------- trace hex

    private fun resetTrace() {
        txTrace.clear()
        rxTrace.clear()
    }

    fun lastTxHex(): String = txTrace.joinToString(" ") { "%02X".format(it) }
    fun lastRxHex(): String = rxTrace.joinToString(" ") { "%02X".format(it) }

    // ---------------------------------------------------------------- bas niveau

    private fun readByte(timeoutMs: Int): Int {
        val deadline = System.currentTimeMillis() + timeoutMs
        while (rx.isEmpty()) {
            val remaining = (deadline - System.currentTimeMillis()).toInt()
            if (remaining <= 0) throw KLineException("Timeout lecture (${timeoutMs} ms)")
            val n = port.read(buf, remaining.coerceAtLeast(10))
            for (i in 0 until n) {
                val v = buf[i].toInt() and 0xFF
                rx.addLast(v)
                rxTrace.add(v)
            }
        }
        return rx.removeFirst()
    }

    /** Purge le buffer logiciel et le buffer RX materiel du FTDI avant une nouvelle trame. */
    fun purgeRx() {
        rx.clear()
        try {
            port.purgeHwBuffers(true, false)
        } catch (_: Exception) {
        }
        try {
            var guard = 0
            while (port.read(buf, 5) > 0 && guard++ < 30) { /* vide les octets residuels */ }
        } catch (e: IOException) {
            throw e
        } catch (_: Exception) {
        }
    }

    /**
     * Envoie un octet sur la ligne K apres un delai inter-octets de 5 ms,
     * puis consomme immediatement l'echo du cable KKL s'il est actif.
     */
    private fun writeByteAndReadEcho(b: Int) {
        Thread.sleep(INTERBYTE_MS)
        val out = b and 0xFF
        txTrace.add(out)
        port.write(byteArrayOf(out.toByte()), 300)
        if (echo) {
            val e = readByte(300)
            if (e != out) {
                throw KLineException(
                    "Echo invalide (%02X au lieu de %02X) [TX=%s | RX=%s]".format(
                        e, out, lastTxHex(), lastRxHex()
                    )
                )
            }
        }
    }

    // ---------------------------------------------------------------- init 5 bauds

    private fun fiveBaud(address: Int) {
        // 7 bits de donnees, parite impaire, 1 bit de stop (7O1) a 5 bauds = 200 ms / bit
        val bits = ArrayList<Int>()
        bits.add(0) // start
        var ones = 0
        for (i in 0 until 7) {
            val bit = (address shr i) and 1
            ones += bit
            bits.add(bit)
        }
        bits.add(if (ones % 2 == 0) 1 else 0) // parite impaire
        bits.add(1) // stop

        val start = System.nanoTime()
        for ((i, bit) in bits.withIndex()) {
            port.setBreak(bit == 0)
            val target = start + (i + 1) * 200_000_000L
            while (true) {
                val left = target - System.nanoTime()
                if (left <= 0) break
                if (left > 3_000_000L) Thread.sleep((left / 1_000_000L) - 2) else Thread.onSpinWait()
            }
        }
        port.setBreak(false)
    }

    private fun isUsbFailure(e: Throwable): Boolean {
        if (e is IOException) return true
        val m = (e.message ?: "").lowercase()
        return m.contains("usb") || m.contains("get_status") || m.contains("baudrate") ||
            m.contains("break") || m.contains("result=-1") || m.contains("device") || m.contains("closed")
    }

    fun connect(address: Int, bauds: List<Int>): String {
        var last: Exception? = null
        for ((i, b) in bauds.withIndex()) {
            try {
                return tryConnect(address, b)
            } catch (e: Exception) {
                if (isUsbFailure(e)) throw e // remonte immediatement pour reinitialiser l'USB FTDI
                last = e
                log("Echec init @%d bauds : %s".format(b, e.message))
                if (i < bauds.size - 1) Thread.sleep(2600) // le calculateur doit se reposer
            }
        }
        throw last ?: KLineException("Echec initialisation")
    }

    private fun tryConnect(address: Int, b: Int): String {
        baud = b
        echo = true
        resetTrace()
        port.setParameters(b, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
        port.setBreak(false)
        Thread.sleep(400) // ligne au repos
        purgeRx()
        log("Init 5 bauds adresse 0x%02X (%d bauds)".format(address, b))
        fiveBaud(address)
        rx.clear()

        // Attente de l'octet de synchro 0x55 (les octets parasites dus au "break" sont ignores)
        val deadline = System.currentTimeMillis() + 1800
        var sync = -1
        val seen = ArrayList<String>()
        while (System.currentTimeMillis() < deadline) {
            val v = try { readByte(350) } catch (_: KLineException) { continue }
            seen.add("%02X".format(v))
            if (v == 0x55) { sync = v; break }
        }
        if (sync != 0x55) {
            val rxHex = if (seen.isEmpty()) "aucun octet recu" else "octets recus: ${seen.joinToString(" ")}"
            throw KLineException("Pas d'octet de synchro 0x55 ($rxHex)")
        }
        val kw1 = readByte(500)
        val kw2 = readByte(500)
        log("Synchro OK (rx: ${seen.joinToString(" ")}), mots cles %02X %02X".format(kw1, kw2))

        Thread.sleep(30)
        val inv = kw2 xor 0xFF
        txTrace.add(inv)
        port.write(byteArrayOf(inv.toByte()), 300)
        // detection de l'echo du cable
        try {
            val e = readByte(150)
            if (e == inv) echo = true else { echo = false; rx.addFirst(e) }
        } catch (_: KLineException) {
            echo = false
        }
        log(if (echo) "Echo cable detecte" else "Pas d'echo cable")

        // Blocs d'identification du calculateur
        val id = StringBuilder()
        var guard = 0
        while (guard++ < 20) {
            val blk = receiveBlock(T_FIRST_BYTE)
            when (blk.title) {
                0xF6 -> {
                    blk.data.forEach { c -> if (c in 0x20..0x7E) id.append(c.toChar()) }
                    id.append(' ')
                    sendBlock(0x09)
                }
                0x09 -> break
                else -> sendBlock(0x09)
            }
        }
        val txt = id.toString().replace(Regex("\\s+"), " ").trim()
        log("Calculateur : $txt")
        return txt
    }

    // ---------------------------------------------------------------- blocs KWP1281

    private fun recvAck(timeout: Int): Int {
        val b = readByte(timeout)
        writeByteAndReadEcho(b xor 0xFF)
        return b
    }

    fun receiveBlock(firstByteTimeoutMs: Int = T_FIRST_BYTE): Block {
        val len = recvAck(firstByteTimeoutMs)
        val cnt = recvAck(T_BYTE)
        counter = cnt
        val title = recvAck(T_BYTE)
        val n = (len - 3).coerceAtLeast(0)
        val data = IntArray(n) { recvAck(T_BYTE) }
        val end = readByte(T_BYTE)
        if (end != 0x03) {
            throw KLineException(
                "Fin de bloc invalide (%02X au lieu de 03) [TX=%s | RX=%s]".format(
                    end, lastTxHex(), lastRxHex()
                )
            )
        }
        return Block(title, data)
    }

    /**
     * Envoie une trame KWP1281 en purgeant d'abord le buffer RX et en respectant
     * strictement pour chaque octet : write(b) -> echo(b) -> complement ECU (~b),
     * puis pour l'octet final 0x03 : write(0x03) -> echo(0x03).
     */
    fun sendBlock(title: Int, data: IntArray = IntArray(0)) {
        Thread.sleep(INTERBLOCK_MS)
        rx.clear()
        counter = (counter + 1) and 0xFF
        val bytes = intArrayOf(data.size + 3, counter, title) + data
        for (b in bytes) {
            val out = b and 0xFF
            writeByteAndReadEcho(out)
            val c = readByte(T_BYTE)
            val expected = out xor 0xFF
            if (c != expected) {
                throw KLineException(
                    "Acquittement ECU invalide (%02X au lieu de %02X pour octet %02X) [TX=%s | RX=%s]".format(
                        c, expected, out, lastTxHex(), lastRxHex()
                    )
                )
            }
        }
        // Octet de fin de bloc 0x03 : echo cable uniquement, pas de complement ECU
        writeByteAndReadEcho(0x03)
    }

    // ---------------------------------------------------------------- commandes

    fun keepAlive() {
        resetTrace()
        sendBlock(0x09)
        receiveBlock(T_GROUP_RESPONSE)
    }

    /**
     * Lit un groupe de mesures (commande 0x29, timeout 1000 ms).
     * - Titre 0xE7 : decoupe en triplets (f, a, b) (combine 0x17 et calculateurs recents).
     * - Titre 0xF4 : retourne les 4 octets bruts [b0, b1, b2, b3] (Simos 2.1 1.6 AKL) sans les couper en triplets.
     * - Titre 0x02 : bloc d'en-tete Simos (envoye a la 1re lecture ou apres 0x07), relance immediatement 0x29 pour lire le 0xF4 suivant.
     * - Titre 0x09 / 0x0A : ACK / NACK (groupe vide ou non supporte).
     */
    fun readGroup(group: Int): GroupResult {
        resetTrace()
        sendBlock(0x29, intArrayOf(group and 0xFF))
        var blk = receiveBlock(T_GROUP_RESPONSE)

        // Si le Simos 2.1 envoie d'abord un bloc d'en-tete 0x02, on relance 0x29 pour obtenir le bloc de donnees 0xF4
        if (blk.title == 0x02) {
            log("Groupe %03d : en-tête Simos 0x02 reçu (%d octets), lecture du bloc 0xF4...".format(group, blk.data.size))
            sendBlock(0x29, intArrayOf(group and 0xFF))
            blk = receiveBlock(T_GROUP_RESPONSE)
        }

        val txHex = lastTxHex()
        val rxHex = lastRxHex()

        return when (blk.title) {
            0xE7 -> {
                if (blk.data.isEmpty()) {
                    val msg = "Groupe %03d : bloc 0xE7 vide | TX=[%s] RX=[%s]".format(group, txHex, rxHex)
                    log(msg)
                    GroupResult(
                        ok = false,
                        values = emptyList(),
                        rawTxHex = txHex,
                        rawRxHex = rxHex,
                        error = "Bloc 0xE7 vide",
                    )
                } else {
                    if (blk.data.size % 3 != 0) {
                        log("Groupe %03d : taille payload 0xE7 non multiple de 3 (%d octets) | RX=[%s]".format(group, blk.data.size, rxHex))
                    }
                    val out = ArrayList<Map<String, Int>>()
                    var i = 0
                    while (i + 2 < blk.data.size) {
                        out.add(mapOf("f" to blk.data[i], "a" to blk.data[i + 1], "b" to blk.data[i + 2]))
                        i += 3
                    }
                    GroupResult(
                        ok = out.isNotEmpty(),
                        values = out,
                        isRawF4 = false,
                        rawBytes = emptyList(),
                        rawTxHex = txHex,
                        rawRxHex = rxHex,
                        error = null,
                    )
                }
            }
            0xF4 -> {
                val rawList = blk.data.map { it and 0xFF }
                if (rawList.isEmpty()) {
                    log("Groupe %03d : bloc 0xF4 vide | TX=[%s] RX=[%s]".format(group, txHex, rxHex))
                    GroupResult(
                        ok = false,
                        values = emptyList(),
                        isRawF4 = true,
                        rawBytes = emptyList(),
                        rawTxHex = txHex,
                        rawRxHex = rxHex,
                        error = "Bloc 0xF4 vide",
                    )
                } else {
                    GroupResult(
                        ok = true,
                        values = emptyList(),
                        isRawF4 = true,
                        rawBytes = rawList,
                        rawTxHex = txHex,
                        rawRxHex = rxHex,
                        error = null,
                    )
                }
            }
            0x09, 0x0A -> {
                val reason = if (blk.title == 0x0A) "NACK 0x0A (groupe non supporté)" else "ACK 0x09 (groupe vide)"
                log("Groupe %03d : %s | TX=[%s] RX=[%s]".format(group, reason, txHex, rxHex))
                GroupResult(
                    ok = false,
                    values = emptyList(),
                    rawTxHex = txHex,
                    rawRxHex = rxHex,
                    error = reason,
                )
            }
            else -> {
                val reason = "Titre bloc inattendu 0x%02X (%d octets)".format(blk.title, blk.data.size)
                log("Groupe %03d : %s | TX=[%s] RX=[%s]".format(group, reason, txHex, rxHex))
                GroupResult(
                    ok = false,
                    values = emptyList(),
                    rawTxHex = txHex,
                    rawRxHex = rxHex,
                    error = reason,
                )
            }
        }
    }

    fun readFaults(): List<Map<String, Int>> {
        resetTrace()
        sendBlock(0x07)
        val out = ArrayList<Map<String, Int>>()
        var guard = 0
        while (guard++ < 30) {
            val blk = receiveBlock(T_FIRST_BYTE)
            if (blk.title != 0xFC) break
            var i = 0
            while (i + 2 < blk.data.size) {
                val code = (blk.data[i] shl 8) or blk.data[i + 1]
                if (code != 0xFFFF) out.add(mapOf("code" to code, "status" to blk.data[i + 2]))
                i += 3
            }
            sendBlock(0x09)
        }
        return out
    }

    /** Efface les codes defaut du calculateur (commande KWP1281 0x05). */
    fun clearFaults(): List<Map<String, Int>> {
        resetTrace()
        log("Envoi commande 0x05 : effacement des codes defaut")
        sendBlock(0x05)
        val out = ArrayList<Map<String, Int>>()
        var guard = 0
        while (guard++ < 20) {
            val blk = receiveBlock(T_FIRST_BYTE)
            if (blk.title != 0xFC) break
            var i = 0
            while (i + 2 < blk.data.size) {
                val code = (blk.data[i] shl 8) or blk.data[i + 1]
                if (code != 0xFFFF) out.add(mapOf("code" to code, "status" to blk.data[i + 2]))
                i += 3
            }
            sendBlock(0x09)
        }
        log("Codes defaut effaces")
        return out
    }

    /**
     * Demarre le Reglage de base (commande KWP1281 0x28) sur un groupe (098 cable Simos 2/M3.8, 060 DBW ME7.5/Simos 3/Marelli).
     * Sur Simos 2.1, le calculateur repond d'abord par un bloc d'en-tete 0x02 : il faut renvoyer 0x28 <group>
     * (verifie en reel sur 06A906019AM) pour obtenir le bloc de donnees actif 0xF4.
     */
    fun startBasicSetting(group: Int): List<Map<String, Int>>? {
        resetTrace()
        log("Entrée en Réglage de base (0x28) groupe %03d...".format(group))
        sendBlock(0x28, intArrayOf(group and 0xFF))
        var blk = receiveBlock(T_FIRST_BYTE)
        if (blk.title == 0x02) {
            log("Groupe %03d : en-tête 0x02 reçu (%d octets), renvoi 0x28 pour lancer l'actionneur...".format(group, blk.data.size))
            sendBlock(0x28, intArrayOf(group and 0xFF))
            blk = receiveBlock(T_FIRST_BYTE)
        }
        return parseBasicSettingBlock(group, blk)
    }

    /**
     * Maintient le Reglage de base actif en relancant 0x28 <group> toutes les 500 ms.
     */
    fun pollBasicSetting(group: Int): List<Map<String, Int>>? {
        resetTrace()
        sendBlock(0x28, intArrayOf(group and 0xFF))
        var blk = receiveBlock(T_GROUP_RESPONSE)
        if (blk.title == 0x02) {
            sendBlock(0x28, intArrayOf(group and 0xFF))
            blk = receiveBlock(T_GROUP_RESPONSE)
        }
        return parseBasicSettingBlock(group, blk)
    }

    private fun parseBasicSettingBlock(group: Int, blk: Block): List<Map<String, Int>>? {
        return when (blk.title) {
            0xF4 -> {
                val hex = blk.data.joinToString(" ") { "%02X".format(it and 0xFF) }
                val dec = blk.data.joinToString(", ") { "%d".format(it and 0xFF) }
                log("Groupe %03d [0xF4] : [%s] (hex: %s)".format(group, dec, hex))
                blk.data.mapIndexed { idx, b -> mapOf("f" to 0xF4, "a" to idx, "b" to (b and 0xFF)) }
            }
            0xE7 -> {
                val out = ArrayList<Map<String, Int>>()
                var i = 0
                while (i + 2 < blk.data.size) {
                    out.add(mapOf("f" to blk.data[i], "a" to blk.data[i + 1], "b" to blk.data[i + 2]))
                    i += 3
                }
                log("Groupe %03d [0xE7] : %d cellules".format(group, out.size))
                out
            }
            else -> {
                log("Groupe %03d : réponse inattendue titre=0x%02X | RX=[%s]".format(group, blk.title, lastRxHex()))
                null
            }
        }
    }

    /** Remise a zero des valeurs d'auto-adaptation moteur (canal 00, commande KWP1281 0x2A). */
    fun resetAdaptations(): Boolean {
        resetTrace()
        log("Envoi commande 0x2A : remise a zero des auto-adaptations (canal 00)")
        sendBlock(0x2A, intArrayOf(0x00, 0x00))
        val blk = receiveBlock(T_FIRST_BYTE)
        val ok = blk.title == 0x09 || blk.title == 0xE6
        if (blk.title != 0x09) {
            sendBlock(0x09)
            receiveBlock(T_FIRST_BYTE)
        }
        log(if (ok) "Auto-adaptations moteur remises a zero" else "Reponse calculateur : 0x%02X".format(blk.title))
        return ok
    }

    fun end() {
        try {
            resetTrace()
            sendBlock(0x06)
        } catch (_: Exception) {
        }
    }
}
