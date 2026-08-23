package com.meckchat.meckchat

import android.content.Intent
import android.net.VpnService
import android.os.ParcelFileDescriptor
import android.util.Log
import com.wireguard.android.backend.GoBackend
import com.wireguard.android.backend.Tunnel
import com.wireguard.config.Config
import com.wireguard.config.InetNetwork
import com.wireguard.config.Interface
import com.wireguard.config.Peer

class MeckChatTunnel(private val tunnelName: String) : Tunnel {
    private var currentState: Tunnel.State = Tunnel.State.DOWN

    override fun getName(): String = tunnelName

    override fun onStateChange(newState: Tunnel.State) {
        currentState = newState
        Log.i("MeckChatTunnel", "WireGuard Tunnel state changed to: $newState")
    }

    fun getState(): Tunnel.State = currentState
}

class MeckChatVpnService : VpnService() {

    private var vpnInterface: ParcelFileDescriptor? = null

    companion object {
        const val ACTION_CONNECT = "com.meckchat.vpn.CONNECT"
        const val ACTION_DISCONNECT = "com.meckchat.vpn.DISCONNECT"
        const val EXTRA_VIRTUAL_IP = "virtual_ip"
        const val EXTRA_PRIVATE_KEY = "private_key"
        const val EXTRA_PEER_PUBLIC_KEY = "peer_public_key"
        const val EXTRA_PEER_VIRTUAL_IP = "peer_virtual_ip"
        const val EXTRA_ENDPOINT = "endpoint"
        const val TAG = "MeckChatVpnService"

        @JvmStatic
        var activeTunnel: MeckChatTunnel? = null
        @JvmStatic
        var backend: GoBackend? = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == ACTION_CONNECT) {
            val virtualIp = intent.getStringExtra(EXTRA_VIRTUAL_IP) ?: "10.77.0.10"
            val privateKey = intent.getStringExtra(EXTRA_PRIVATE_KEY) ?: ""
            val peerPublicKey = intent.getStringExtra(EXTRA_PEER_PUBLIC_KEY) ?: ""
            val peerVirtualIp = intent.getStringExtra(EXTRA_PEER_VIRTUAL_IP) ?: ""
            val endpoint = intent.getStringExtra(EXTRA_ENDPOINT)
            startVpnTunnel(virtualIp, privateKey, peerPublicKey, peerVirtualIp, endpoint)
        } else if (action == ACTION_DISCONNECT) {
            stopVpnTunnel()
        }
        return START_STICKY
    }

    private fun startVpnTunnel(
        virtualIp: String,
        privateKey: String,
        peerPublicKey: String,
        peerVirtualIp: String,
        endpoint: String?
    ) {
        try {
            Log.i(TAG, "Starting MeckChat WireGuard Engine on $virtualIp/16...")

            if (backend == null) {
                backend = GoBackend(applicationContext)
            }
            if (activeTunnel == null) {
                activeTunnel = MeckChatTunnel("meckchat0")
            }

            if (privateKey.isNotEmpty() && peerPublicKey.isNotEmpty() && peerVirtualIp.isNotEmpty()) {
                val interfaceBuilder = Interface.Builder()
                    .parsePrivateKey(privateKey)
                    .addAddress(InetNetwork.parse("$virtualIp/16"))
                    .setListenPort(51820)

                val peerBuilder = Peer.Builder()
                    .parsePublicKey(peerPublicKey)
                    .addAllowedIp(InetNetwork.parse("$peerVirtualIp/32"))

                if (!endpoint.isNullOrEmpty()) {
                    peerBuilder.parseEndpoint(endpoint)
                }
                peerBuilder.setPersistentKeepalive(25)

                val config = Config.Builder()
                    .setInterface(interfaceBuilder.build())
                    .addPeer(peerBuilder.build())
                    .build()

                backend?.setState(activeTunnel!!, Tunnel.State.UP, config)
                Log.i(TAG, "MeckChat WireGuard Tunnel successfully started via GoBackend!")
            } else {
                val builder = Builder()
                    .setSession("MeckChat WireGuard Tunnel")
                    .addAddress(virtualIp, 16)
                    .addRoute("10.77.0.0", 16)
                    .setMtu(1420)

                vpnInterface = builder.establish()
                Log.i(TAG, "Fallback MeckChat VPN Interface established.")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish WireGuard VPN Tunnel: ${e.message}", e)
        }
    }

    private fun stopVpnTunnel() {
        try {
            if (activeTunnel != null && backend != null) {
                backend?.setState(activeTunnel!!, Tunnel.State.DOWN, null)
            }
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
