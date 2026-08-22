package com.meckchat.meckchat

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log

class MeckChatVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null

    companion object {
        const val ACTION_CONNECT = "com.meckchat.vpn.CONNECT"
        const val ACTION_DISCONNECT = "com.meckchat.vpn.DISCONNECT"
        const val EXTRA_VIRTUAL_IP = "virtual_ip"
        const val TAG = "MeckChatVpnService"
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_CONNECT) {
            val virtualIp = intent.getStringExtra(EXTRA_VIRTUAL_IP) ?: "10.77.0.10"
            startVpnTunnel(virtualIp)
        } else if (action == ACTION_DISCONNECT) {
            stopVpnTunnel()
        }
        return START_STICKY
    }

    private fun startVpnTunnel(virtualIp: String) {
        try {
            if (vpnInterface != null) {
                stopVpnTunnel()
            }

            Log.i(TAG, "Starting MeckChat WireGuard VPN Interface on $virtualIp/16...")
            val builder = Builder()
                .setSession("MeckChat WireGuard Tunnel")
                .addAddress(virtualIp, 16)
                .addRoute("10.77.0.0", 16)
                .setMtu(1420)

            vpnInterface = builder.establish()
            Log.i(TAG, "MeckChat WireGuard VPN Interface successfully established!")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish WireGuard VPN Interface: ${e.message}", e)
        }
    }

    private fun stopVpnTunnel() {
        try {
            vpnInterface?.close()
            vpnInterface = null
            stopSelf()
            Log.i(TAG, "MeckChat WireGuard VPN Interface stopped.")
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping VPN Interface: ${e.message}", e)
        }
    }

    override fun onDestroy() {
        stopVpnTunnel()
        super.onDestroy()
    }
}
