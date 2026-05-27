/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.KeyEvent
import android.widget.Button
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

class SetupActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "PulsarOS.Setup"
        private const val PREFS = "pulsaros_setup"
        private const val KEY_COMPLETED = "setup_completed"
        private const val MAX_STEP = 3
    }

    private var step = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "SetupActivity created")

        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        if (prefs.getBoolean(KEY_COMPLETED, false)) {
            Log.i(TAG, "Setup already completed, launching console")
            launchConsole()
            return
        }

        setContentView(R.layout.activity_setup)
        setupButtons()
        updateStep()
    }

    private fun setupButtons() {
        findViewById<Button>(R.id.btn_next).setOnClickListener { nextStep() }
        findViewById<Button>(R.id.btn_skip).setOnClickListener { skipAll() }
    }

    private fun nextStep() {
        Log.i(TAG, "Next step: $step → ${step + 1}")
        if (step < MAX_STEP) {
            step++
            updateStep()
        } else {
            completeSetup()
        }
    }

    private fun skipAll() {
        Log.i(TAG, "User skipped setup")
        completeSetup()
    }

    private fun updateStep() {
        val title = findViewById<TextView>(R.id.tv_title)
        val desc = findViewById<TextView>(R.id.tv_desc)
        when (step) {
            0 -> { title.setText(R.string.step_welcome); desc.setText(R.string.step_welcome_desc) }
            1 -> { title.setText(R.string.step_gamepad); desc.setText(R.string.step_gamepad_desc) }
            2 -> { title.setText(R.string.step_network); desc.setText(R.string.step_network_desc) }
            3 -> { title.setText(R.string.step_done); desc.setText(R.string.step_done_desc) }
        }
    }

    private fun completeSetup() {
        getSharedPreferences(PREFS, MODE_PRIVATE)
            .edit().putBoolean(KEY_COMPLETED, true).apply()
        launchConsole()
    }

    private fun launchConsole() {
        val launcherPkg = listOf(
            "com.pulsaros.consolelauncher",
            "org.esde.emulationstation",
            "com.retroarch"
        ).firstOrNull { pkg ->
            runCatching { packageManager.getPackageInfo(pkg, 0) }.isSuccess
        }

        val intent = launcherPkg?.let {
            packageManager.getLaunchIntentForPackage(it)
        } ?: Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }

        Log.i(TAG, "Launching: ${intent.component?.packageName ?: "system home"}")
        startActivity(intent)
        finish()
    }

    // Gamepad support
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_BUTTON_A -> {
                findViewById<Button>(R.id.btn_next).performClick()
                return true
            }
            KeyEvent.KEYCODE_BUTTON_B -> {
                findViewById<Button>(R.id.btn_skip).performClick()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}