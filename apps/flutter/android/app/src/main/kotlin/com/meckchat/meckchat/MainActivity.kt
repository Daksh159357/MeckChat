package com.meckchat.meckchat

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.wireguard.android.backend.GoBackend
import com.wireguard.crypto.Key

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.meckchat/wireguard_vpn"
    private val VPN_REQUEST_CODE = 0x2026

    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> {
                    val intent = VpnService.prepare(this)
                    if (intent != null) {
                        pendingResult = result
                        startActivityForResult(intent, VPN_REQUEST_CODE)
                    } else {
                        result.success(true)
                    }
                }
                "startVpn" -> {
                    val virtualIp = call.argument<String>("virtual_ip") ?: "10.77.0.10"
                    val privateKey = call.argument<String>("private_key") ?: ""
                    val peerPublicKey = call.argument<String>("peer_public_key") ?: ""
                    val peerVirtualIp = call.argument<String>("peer_virtual_ip") ?: ""
                    val endpoint = call.argument<String>("endpoint")

                    val intent = Intent(this, MeckChatVpnService::class.java).apply {
                        action = MeckChatVpnService.ACTION_CONNECT
                        putExtra(MeckChatVpnService.EXTRA_VIRTUAL_IP, virtualIp)
                        putExtra(MeckChatVpnService.EXTRA_PRIVATE_KEY, privateKey)
                        putExtra(MeckChatVpnService.EXTRA_PEER_PUBLIC_KEY, peerPublicKey)
                        putExtra(MeckChatVpnService.EXTRA_PEER_VIRTUAL_IP, peerVirtualIp)
                        if (endpoint != null) {
                            putExtra(MeckChatVpnService.EXTRA_ENDPOINT, endpoint)
                        }
                    }
                    startService(intent)
                    result.success(true)
                }
                "stopVpn" -> {
                    val intent = Intent(this, MeckChatVpnService::class.java).apply {
                        action = MeckChatVpnService.ACTION_DISCONNECT
                    }
                    startService(intent)
                    result.success(true)
                }
                "getTunnelStats" -> {
                    val peerPublicKeyStr = call.argument<String>("peer_public_key") ?: ""
                    val statsMap = mutableMapOf<String, Any>()

                    try {
                        val backend = MeckChatVpnService.backend ?: GoBackend(context)
                        val tunnel = MeckChatVpnService.activeTunnel
                        if (tunnel != null) {
                            val statistics = backend.getStatistics(tunnel)
                            val rx = statistics.totalRx()
                            val tx = statistics.totalTx()
                            var handshakeSecsAgo: Long = -1

                            if (peerPublicKeyStr.isNotEmpty()) {
                                try {
                                    val key = Key.fromBase64(peerPublicKeyStr)
                                    val lastHandshakeMs = statistics.latestHandshake(key)
                                    if (lastHandshakeMs > 0) {
                                        handshakeSecsAgo = (System.currentTimeMillis() - lastHandshakeMs) / 1000
                                    }
                                } catch (_: Exception) {}
                            }

                            val isConnected = handshakeSecsAgo in 0..180
                            statsMap["status"] = if (isConnected) "Connected" else "Connecting"
                            statsMap["rx_bytes"] = rx
                            statsMap["tx_bytes"] = tx
                            statsMap["handshake_secs_ago"] = handshakeSecsAgo
                        } else {
                            statsMap["status"] = "Disconnected"
                            statsMap["rx_bytes"] = 0L
                            statsMap["tx_bytes"] = 0L
                            statsMap["handshake_secs_ago"] = -1L
                        }
                    } catch (e: Exception) {
                        statsMap["status"] = "Disconnected"
                        statsMap["rx_bytes"] = 0L
                        statsMap["tx_bytes"] = 0L
                        statsMap["handshake_secs_ago"] = -1L
                    }
                    result.success(statsMap)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val isGranted = resultCode == Activity.RESULT_OK
            pendingResult?.success(isGranted)
            pendingResult = null
        }
    }
}
