/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action != Intent.ACTION_BOOT_COMPLETED) return
        Log.i(TAG, "Boot completed, checking setup status")

        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_COMPLETED, false)) {
            Log.i(TAG, "First boot — launching SetupActivity")
            val i = Intent(context, SetupActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            context.startActivity(i)
        }
    }

    companion object {
        private const val TAG = "PulsarOS.Boot"
        private const val PREFS = "pulsaros_setup"
        private const val KEY_COMPLETED = "setup_completed"
    }
}