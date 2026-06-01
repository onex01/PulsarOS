/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.content.Context
import android.content.Intent
import android.hardware.display.DisplayManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Bundle
import android.os.LocaleList
import android.provider.Settings
import android.util.Log
import android.view.Display
import android.view.InputDevice
import android.view.KeyEvent
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import java.util.Locale
import kotlin.math.abs

class SetupActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "PulsarOS.Setup"
        private const val PREFS = "pulsaros_setup"
        private const val KEY_COMPLETED = "setup_completed"
        private const val KEY_LICENSE_ACCEPTED = "license_accepted"
        private const val KEY_LANGUAGE = "language_code"
        private const val MAX_STEP = 6
    }

    private var step = 0
    private lateinit var titleView: TextView
    private lateinit var descView: TextView
    private lateinit var languageSpinner: Spinner
    private lateinit var statusView: TextView
    private lateinit var btnNext: Button
    private lateinit var btnPrev: Button
    private lateinit var btnSkip: Button
    private lateinit var btnAction: Button
    private lateinit var prefs: android.content.SharedPreferences

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "SetupActivity created")

        prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        if (prefs.getBoolean(KEY_COMPLETED, false)) {
            Log.i(TAG, "Setup already completed, launching console")
            launchConsole()
            return
        }

        setContentView(R.layout.activity_setup)
        titleView = findViewById(R.id.tv_title)
        descView = findViewById(R.id.tv_desc)
        languageSpinner = findViewById(R.id.spinner_language)
        statusView = findViewById(R.id.tv_status)
        btnNext = findViewById(R.id.btn_next)
        btnPrev = findViewById(R.id.btn_prev)
        btnSkip = findViewById(R.id.btn_skip)
        btnAction = findViewById(R.id.btn_action)

        initLanguageSpinner()
        setupButtons()
        updateStep()
    }

    private fun initLanguageSpinner() {
        val adapter = ArrayAdapter.createFromResource(
            this,
            R.array.setup_languages,
            android.R.layout.simple_spinner_item
        ).also {
            it.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
        }
        languageSpinner.adapter = adapter

        val selectedCode = prefs.getString(KEY_LANGUAGE, "system") ?: "system"
        val selectedPosition = when (selectedCode) {
            "ru" -> 1
            "en" -> 2
            else -> 0
        }
        languageSpinner.setSelection(selectedPosition)
    }

    private fun setupButtons() {
        btnNext.setOnClickListener { nextStep() }
        btnPrev.setOnClickListener { previousStep() }
        btnSkip.setOnClickListener { skipAll() }
        btnAction.setOnClickListener { handleAction() }
    }

    private fun nextStep() {
        Log.i(TAG, "Next step: $step → ${step + 1}")
        when (step) {
            0 -> applySelectedLanguage()
            1 -> if (!prefs.getBoolean(KEY_LICENSE_ACCEPTED, false)) {
                openLicenseScreen()
                return
            }
            2 -> if (!hasGamepad()) {
                showConfirmAdvance(
                    R.string.dialog_no_gamepad_title,
                    R.string.dialog_no_gamepad_message
                )
                return
            }
            3 -> if (!isNetworkAvailable()) {
                showConfirmAdvance(
                    R.string.dialog_no_network_title,
                    R.string.dialog_no_network_message
                )
                return
            }
        }

        if (step < MAX_STEP) {
            step++
            updateStep()
        } else {
            completeSetup()
        }
    }

    private fun previousStep() {
        if (step > 0) {
            step--
            updateStep()
        }
    }

    private fun skipAll() {
        Log.i(TAG, "User skipped setup")
        completeSetup()
    }

    private fun showConfirmAdvance(titleRes: Int, messageRes: Int) {
        AlertDialog.Builder(this)
            .setTitle(titleRes)
            .setMessage(messageRes)
            .setPositiveButton(R.string.dialog_continue) { _, _ ->
                if (step < MAX_STEP) {
                    step++
                    updateStep()
                } else {
                    completeSetup()
                }
            }
            .setNegativeButton(R.string.dialog_go_back, null)
            .setCancelable(true)
            .show()
    }

    private fun updateStep() {
        titleView.text = when (step) {
            0 -> getString(R.string.step_language)
            1 -> getString(R.string.step_license)
            2 -> getString(R.string.step_gamepad)
            3 -> getString(R.string.step_network)
            4 -> getString(R.string.step_display)
            5 -> getString(R.string.step_storage)
            6 -> getString(R.string.step_done)
            else -> getString(R.string.step_language)
        }

        descView.text = when (step) {
            0 -> getString(R.string.step_language_desc)
            1 -> getString(R.string.step_license_desc)
            2 -> getString(R.string.step_gamepad_desc)
            3 -> getString(R.string.step_network_desc)
            4 -> getString(R.string.step_display_desc)
            5 -> getString(R.string.step_storage_desc)
            6 -> getString(R.string.step_done_desc)
            else -> ""
        }

        languageSpinner.visibility = if (step == 0) View.VISIBLE else View.GONE
        btnPrev.visibility = if (step > 0) View.VISIBLE else View.GONE

        statusView.text = when (step) {
            0 -> getString(R.string.status_language_selected, getSelectedLanguageName())
            1 -> getString(
                if (prefs.getBoolean(KEY_LICENSE_ACCEPTED, false)) R.string.status_license_accepted
                else R.string.status_license_pending
            )
            2 -> if (hasGamepad()) getString(R.string.status_gamepad_connected) else getString(R.string.status_gamepad_missing)
            3 -> if (isNetworkAvailable()) getString(R.string.status_network_connected) else getString(R.string.status_network_disconnected)
            4 -> getString(
                R.string.status_display_info,
                getCurrentDisplay()?.refreshRate ?: 0f,
                getMaxSupportedRefreshRate()
            )
            5 -> scanStorageStatus()
            6 -> getString(R.string.status_ready)
            else -> ""
        }

        btnAction.visibility = when (step) {
            1, 2, 3, 4, 5 -> View.VISIBLE
            else -> View.GONE
        }

        btnAction.text = when (step) {
            1 -> getString(R.string.btn_action_show_license)
            2 -> getString(R.string.btn_action_open_bt)
            3 -> getString(R.string.btn_action_open_network)
            4 -> getString(
                if (isMaxRefreshRateActive()) R.string.btn_action_display else R.string.btn_action_set_display
            )
            5 -> getString(R.string.btn_action_refresh)
            else -> ""
        }

        btnNext.text = if (step == MAX_STEP) getString(R.string.btn_finish) else getString(R.string.btn_next)
    }

    private fun handleAction() {
        when (step) {
            1 -> openLicenseScreen()
            2 -> if (!hasGamepad()) openBluetoothSettings() else Toast.makeText(this, R.string.status_gamepad_connected, Toast.LENGTH_SHORT).show()
            3 -> openWifiSettings()
            4 -> {
                if (!applyMaxRefreshRate()) openDisplaySettings()
            }
            5 -> updateStep()
        }
    }

    private fun getSelectedLanguageName(): String {
        return languageSpinner.selectedItem?.toString() ?: getString(R.string.status_language_system)
    }

    private fun getSelectedLanguageCode(): String {
        return when (languageSpinner.selectedItemPosition) {
            1 -> "ru"
            2 -> "en"
            else -> "system"
        }
    }

    private fun applySelectedLanguage() {
        val selectedCode = getSelectedLanguageCode()
        prefs.edit().putString(KEY_LANGUAGE, selectedCode).apply()

        if (selectedCode != "system") {
            val locale = Locale(selectedCode)
            Locale.setDefault(locale)
            val config = resources.configuration
            config.setLocales(LocaleList(locale))
            resources.updateConfiguration(config, resources.displayMetrics)
            Toast.makeText(this, getString(R.string.toast_language_set, getSelectedLanguageName()), Toast.LENGTH_SHORT).show()
            recreate()
        }
    }

    private fun openLicenseScreen() {
        startActivity(Intent(this, LicenseWarningActivity::class.java))
    }

    private fun getCurrentDisplay(): Display? {
        val dm = getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
        return dm?.getDisplay(Display.DEFAULT_DISPLAY)
    }

    private fun getMaxSupportedRefreshRate(): Float {
        val display = getCurrentDisplay() ?: return 60f
        return display.supportedModes.maxOfOrNull { it.refreshRate } ?: display.refreshRate
    }

    private fun isMaxRefreshRateActive(): Boolean {
        val display = getCurrentDisplay() ?: return false
        return abs(display.refreshRate - getMaxSupportedRefreshRate()) < 0.5f
    }

    private fun applyMaxRefreshRate(): Boolean {
        val display = getCurrentDisplay() ?: return false
        val maxRate = getMaxSupportedRefreshRate()
        if (abs(display.refreshRate - maxRate) < 0.5f) {
            Toast.makeText(this, R.string.toast_display_already_max, Toast.LENGTH_LONG).show()
            return true
        }

        if (!Settings.System.canWrite(this)) {
            Toast.makeText(this, R.string.toast_display_permissions_required, Toast.LENGTH_LONG).show()
            return false
        }

        val successMin = Settings.System.putFloat(contentResolver, "min_refresh_rate", maxRate)
        val successPeak = Settings.System.putFloat(contentResolver, "peak_refresh_rate", maxRate)

        if (successMin && successPeak) {
            Toast.makeText(this, getString(R.string.toast_display_set_max, maxRate), Toast.LENGTH_LONG).show()
            updateStep()
            return true
        }

        Toast.makeText(this, R.string.toast_display_set_failed, Toast.LENGTH_LONG).show()
        return false
    }

    private fun hasGamepad(): Boolean {
        val ids = InputDevice.getDeviceIds()
        return ids.any { id ->
            val device = InputDevice.getDevice(id)
            if (device == null || device.isVirtual) return@any false
            device.supportsSource(InputDevice.SOURCE_GAMEPAD) ||
                device.supportsSource(InputDevice.SOURCE_JOYSTICK) ||
                device.supportsSource(InputDevice.SOURCE_DPAD)
        }
    }

    private fun isNetworkAvailable(): Boolean {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return false
        val activeNetwork = cm.activeNetwork ?: return false
        val caps = cm.getNetworkCapabilities(activeNetwork) ?: return false
        return caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) ||
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
    }

    private fun scanStorageStatus(): String {
        val volumes = StorageScanner.scanAll(this)
        if (volumes.isEmpty()) {
            return getString(R.string.status_storage_none)
        }

        return volumes.joinToString(separator = "\n") { volume ->
            val pulsar = if (volume.hasPulsarOS) getString(R.string.status_storage_pulsaros) else getString(R.string.status_storage_missing)
            val roms = if (volume.hasRoms) getString(R.string.status_storage_roms) else getString(R.string.status_storage_no_roms)
            "${volume.path}: ${formatBytes(volume.freeBytes)} — $pulsar, $roms"
        }
    }

    private fun formatBytes(bytes: Long): String {
        val kb = 1024L
        val mb = kb * 1024
        return when {
            bytes >= mb -> String.format(Locale.US, "%.1f MB", bytes.toDouble() / mb)
            bytes >= kb -> String.format(Locale.US, "%.1f KB", bytes.toDouble() / kb)
            else -> "$bytes B"
        }
    }

    private fun openWifiSettings() {
        try {
            startActivity(Intent(Settings.Panel.ACTION_INTERNET_CONNECTIVITY))
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
        }
    }

    private fun openBluetoothSettings() {
        try {
            startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
        } catch (e: Exception) {
            startActivity(Intent(Settings.ACTION_SETTINGS))
        }
    }

    private fun openDisplaySettings() {
        startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS))
    }

    private fun showLicenseDialog() {
        val licenses = listOf(
            getString(R.string.license_console_launcher),
            getString(R.string.license_retroarch),
            getString(R.string.license_emulationstation),
            getString(R.string.license_kodi),
            getString(R.string.license_tvbro)
        )

        AlertDialog.Builder(this)
            .setTitle(R.string.dialog_license_title)
            .setMessage(licenses.joinToString(separator = "\n\n"))
            .setPositiveButton(R.string.dialog_accept) { _, _ ->
                prefs.edit().putBoolean(KEY_LICENSE_ACCEPTED, true).apply()
                updateStep()
            }
            .setNegativeButton(R.string.dialog_decline) { _, _ ->
                Toast.makeText(this, R.string.toast_license_required, Toast.LENGTH_LONG).show()
                finish()
            }
            .setCancelable(false)
            .show()
    }

    private fun completeSetup() {
        prefs.edit().putBoolean(KEY_COMPLETED, true).apply()
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

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_BUTTON_A -> {
                btnNext.performClick()
                return true
            }
            KeyEvent.KEYCODE_BUTTON_B -> {
                btnSkip.performClick()
                return true
            }
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                btnPrev.performClick()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onResume() {
        super.onResume()
        updateStep()
    }
}

    private fun scanStorageStatus(): String {
        val volumes = StorageScanner.scanAll(this)
        if (volumes.isEmpty()) {
            return getString(R.string.status_storage_none)
        }

        return volumes.joinToString(separator = "\n") { volume ->
            val pulsar = if (volume.hasPulsarOS) getString(R.string.status_storage_pulsaros) else getString(R.string.status_storage_missing)
            val roms = if (volume.hasRoms) getString(R.string.status_storage_roms) else getString(R.string.status_storage_no_roms)
            "${volume.path}: ${formatBytes(volume.freeBytes)} — $pulsar, $roms"
        }
    }

    private fun formatBytes(bytes: Long): String {
        val kb = 1024L
        val mb = kb * 1024
        return when {
            bytes >= mb -> String.format(Locale.US, "%.1f MB", bytes.toDouble() / mb)
            bytes >= kb -> String.format(Locale.US, "%.1f KB", bytes.toDouble() / kb)
            else -> "$bytes B"
        }
    }

    private fun openWifiSettings() {
        startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
    }

    private fun openDisplaySettings() {
        startActivity(Intent(Settings.ACTION_DISPLAY_SETTINGS))
    }

    private fun showLicenseDialog() {
        val licenses = listOf(
            getString(R.string.license_console_launcher),
            getString(R.string.license_retroarch),
            getString(R.string.license_emulationstation),
            getString(R.string.license_kodi),
            getString(R.string.license_tvbro)
        )

        AlertDialog.Builder(this)
            .setTitle(R.string.dialog_license_title)
            .setMessage(licenses.joinToString(separator = "\n\n"))
            .setPositiveButton(R.string.dialog_accept) { _, _ ->
                getSharedPreferences(PREFS, MODE_PRIVATE).edit()
                    .putBoolean(KEY_LICENSE_ACCEPTED, true)
                    .apply()
                updateStep()
            }
            .setNegativeButton(R.string.dialog_decline) { _, _ ->
                Toast.makeText(this, R.string.toast_license_required, Toast.LENGTH_LONG).show()
                finish()
            }
            .setCancelable(false)
            .show()
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

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_BUTTON_A -> {
                btnNext.performClick()
                return true
            }
            KeyEvent.KEYCODE_BUTTON_B -> {
                btnSkip.performClick()
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
