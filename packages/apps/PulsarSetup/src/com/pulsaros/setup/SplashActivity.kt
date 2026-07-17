/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.content.Intent
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity

class SplashActivity : AppCompatActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i("PulsarOS.Splash", "SplashActivity — skipping splash, launching setup")

        val prefs = getSharedPreferences("pulsaros_setup", MODE_PRIVATE)
        val setupCompleted = prefs.getBoolean("setup_completed", false)

        val target = if (setupCompleted) {
            launchConsoleIntent()
        } else {
            Intent(this, SetupActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }
        }
        startActivity(target)
        finish()
    }

    private fun launchConsoleIntent(): Intent {
        val launcherPkg = listOf(
            "com.pulsaros.consolelauncher",
            "org.esde.emulationstation",
            "com.retroarch"
        ).firstOrNull { pkg ->
            runCatching { packageManager.getPackageInfo(pkg, 0) }.isSuccess
        }

        return launcherPkg?.let {
            packageManager.getLaunchIntentForPackage(it)
        } ?: Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
    }
}
