package com.adguard.trusttunnel

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class ToggleVpnTileService : TileService() {

    override fun onClick() {
        super.onClick()

        // Optional: show "active" state briefly while we fire the action
        val tile = qsTile
        tile?.state = Tile.STATE_ACTIVE
        tile?.updateTile()

        // Launch MainActivity with the same extra that your Flutter code expects.
        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            putExtra("type", "toggle_vpn")
        }

        startActivityAndCollapse(intent)
    }

    override fun onStartListening() {
        super.onStartListening()
        // You could later update tile state based on VPN status via a broadcast, if desired.
    }

    override fun onStopListening() {
        super.onStopListening()
    }
}
