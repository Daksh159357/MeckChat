package com.meckchat.meckchat

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                        result.success(true) // Permission already granted
                    }
                }
                "startVpn" -> {
                    val virtualIp = call.argument<String>("virtual_ip") ?: "10.77.0.10"
                    val intent = Intent(this, MeckChatVpnService::class.java).apply {
                        action = MeckChatVpnService.ACTION_CONNECT
                        putExtra(MeckChatVpnService.EXTRA_VIRTUAL_IP, virtualIp)
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
