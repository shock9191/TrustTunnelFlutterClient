package com.adguard.trusttunnel

import android.content.Intent
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class ToggleVpnTileService : TileService() {

    override fun onClick() {
        super.onClick()

        val tile = qsTile
        tile?.state = Tile.STATE_ACTIVE
        tile?.updateTile()

        // Launch MainActivity with a custom action that we detect in MainActivity
        val intent = Intent(this, MainActivity::class.java).apply {
            action = "com.adguard.trusttunnel.TOGGLE_VPN"
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivityAndCollapse(intent)
    }

    override fun onStartListening() {
        super.onStartListening()
    }

    override fun onStopListening() {
        super.onStopListening()
    }
}
