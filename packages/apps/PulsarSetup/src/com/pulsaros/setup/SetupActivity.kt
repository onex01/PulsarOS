/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.app.AlertDialog
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbManager
import android.hardware.display.DisplayManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.LocaleList
import android.provider.Settings
import android.util.Log
import android.view.Display
import android.view.InputDevice
import android.view.KeyEvent
import android.view.View
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ProgressBar
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
    }

    // Step order: gamepad FIRST, then language, license, welcome, calibration, network, display, storage, done
    private val steps = intArrayOf(
        R.string.step_gamepad,       // 0
        R.string.step_language,      // 1
        R.string.step_license,       // 2
        R.string.step_welcome,       // 3
        R.string.step_gamepad_calibrate, // 4
        R.string.step_network,       // 5
        R.string.step_display,       // 6
        R.string.step_storage,       // 7
        R.string.step_done           // 8
    )
    private val stepDescs = intArrayOf(
        R.string.step_gamepad_desc,
        R.string.step_language_desc,
        R.string.step_license_desc,
        R.string.step_welcome_desc,
        R.string.step_gamepad_calibrate_desc,
        R.string.step_network_desc,
        R.string.step_display_desc,
        R.string.step_storage_desc,
        R.string.step_done_desc
    )
    private val MAX_STEP = steps.size - 1

    private var step = 0
    private var inputMethod = InputMethod.UNKNOWN
    private var detectedGamepad: InputDevice? = null
    private var isBluetoothScanning = false
    private var calibrationStep = 0

    private lateinit var titleView: TextView
    private lateinit var descView: TextView
    private lateinit var languageSpinner: Spinner
    private lateinit var statusView: TextView
    private lateinit var progressBar: ProgressBar
    private lateinit var btnNext: Button
    private lateinit var btnPrev: Button
    private lateinit var btnSkip: Button
    private lateinit var btnAction: Button
    private lateinit var stepIndicator: TextView
    private lateinit var prefs: android.content.SharedPreferences
    private lateinit var handler: Handler

    private var btScanner: BluetoothLeScanner? = null
    private val knownBtGamepads = mutableSetOf<String>()

    private enum class InputMethod {
        UNKNOWN, GAMEPAD, KEYBOARD_MOUSE
    }

    private val usbReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                UsbManager.ACTION_USB_DEVICE_ATTACHED -> {
                    Log.i(TAG, "USB device attached")
                    handler.post { checkGamepadStatus() }
                }
                UsbManager.ACTION_USB_DEVICE_DETACHED -> {
                    Log.i(TAG, "USB device detached")
                    handler.post { checkGamepadStatus() }
                }
            }
        }
    }

    private val btReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothDevice.ACTION_ACL_CONNECTED -> {
                    Log.i(TAG, "BT device connected")
                    handler.post { checkGamepadStatus() }
                }
                BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                    Log.i(TAG, "BT device disconnected")
                    handler.post { checkGamepadStatus() }
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.i(TAG, "SetupActivity created")

        handler = Handler(Looper.getMainLooper())
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
        progressBar = findViewById(R.id.progress_bar)
        btnNext = findViewById(R.id.btn_next)
        btnPrev = findViewById(R.id.btn_prev)
        btnSkip = findViewById(R.id.btn_skip)
        btnAction = findViewById(R.id.btn_action)
        stepIndicator = findViewById(R.id.tv_step_indicator)

        initLanguageSpinner()
        setupButtons()
        registerReceivers()
        detectInputMethod()
        updateStep()
    }

    private fun registerReceivers() {
        val usbFilter = IntentFilter().apply {
            addAction(UsbManager.ACTION_USB_DEVICE_ATTACHED)
            addAction(UsbManager.ACTION_USB_DEVICE_DETACHED)
        }
        registerReceiver(usbReceiver, usbFilter)

        val btFilter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        registerReceiver(btReceiver, btFilter)
    }

    private fun detectInputMethod() {
        val gamepads = GamepadManager.getWhitelistedGamepads()
        if (gamepads.isNotEmpty()) {
            inputMethod = InputMethod.GAMEPAD
            detectedGamepad = gamepads.first()
            Log.i(TAG, "Whitelisted gamepad found: ${GamepadManager.getGamepadName(gamepads.first())}")
        } else if (GamepadManager.hasKeyboardOrMouse()) {
            inputMethod = InputMethod.KEYBOARD_MOUSE
            Log.i(TAG, "Keyboard/mouse detected")
        } else {
            inputMethod = InputMethod.UNKNOWN
        }
    }

    private fun checkGamepadStatus() {
        detectInputMethod()
        if (step == 0 || step == 4) {
            updateStep()
        }
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

        val systemLocale = resources.configuration.locales[0]?.language ?: "en"
        val selectedCode = prefs.getString(KEY_LANGUAGE, null) ?: systemLocale
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
        Log.i(TAG, "Next step: $step -> ${step + 1}")
        when (step) {
            0 -> {
                // Gamepad step - warn if no gamepad but allow proceeding
                if (inputMethod == InputMethod.UNKNOWN) {
                    showConfirmAdvance(
                        R.string.dialog_no_gamepad_title,
                        R.string.dialog_no_gamepad_message
                    )
                    return
                }
            }
            1 -> applySelectedLanguage()
            2 -> if (!prefs.getBoolean(KEY_LICENSE_ACCEPTED, false)) {
                showLicenseDialog()
                return
            }
            4 -> {
                // Calibration step - always proceed
            }
            5 -> if (!isNetworkAvailable()) {
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
        AlertDialog.Builder(this, R.style.Theme_PulsarSetup_Dialog)
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
        titleView.text = getString(steps[step])
        descView.text = getString(stepDescs[step])
        stepIndicator.text = "ШАГ ${step + 1} / ${MAX_STEP + 1}"

        // Language spinner: only visible on language step
        languageSpinner.visibility = if (step == 1) View.VISIBLE else View.GONE

        // Prev button: hidden on first step
        btnPrev.visibility = if (step > 0) View.VISIBLE else View.GONE

        // Status text
        statusView.text = when (step) {
            0 -> getGamepadStatusText()
            1 -> getString(R.string.status_language_selected, getSelectedLanguageName())
            2 -> getString(
                if (prefs.getBoolean(KEY_LICENSE_ACCEPTED, false)) R.string.status_license_accepted
                else R.string.status_license_pending
            )
            3 -> getString(R.string.status_ready)
            4 -> getCalibrationStatusText()
            5 -> if (isNetworkAvailable()) getString(R.string.status_network_connected) else getString(R.string.status_network_disconnected)
            6 -> getString(
                R.string.status_display_info,
                getCurrentDisplay()?.refreshRate ?: 0f,
                getMaxSupportedRefreshRate()
            )
            7 -> scanStorageStatus()
            8 -> getString(R.string.status_ready)
            else -> ""
        }

        // Action button
        btnAction.visibility = when (step) {
            0, 2, 5, 6, 7 -> View.VISIBLE
            else -> View.GONE
        }

        btnAction.text = when (step) {
            0 -> if (inputMethod == InputMethod.GAMEPAD) getString(R.string.btn_action_gamepad_connected)
                  else getString(R.string.btn_action_open_bt)
            2 -> getString(R.string.btn_action_show_license)
            5 -> getString(R.string.btn_action_open_network)
            6 -> getString(
                if (isMaxRefreshRateActive()) R.string.btn_action_display else R.string.btn_action_set_display
            )
            7 -> getString(R.string.btn_action_refresh)
            else -> ""
        }

        // Next button
        btnNext.text = if (step == MAX_STEP) getString(R.string.btn_finish) else getString(R.string.btn_next)

        // Skip button: hidden on gamepad calibration and done steps
        btnSkip.visibility = if (step in listOf(4, 8)) View.GONE else View.VISIBLE

        // Progress bar: only during BT scan
        progressBar.visibility = if (step == 0 && isBluetoothScanning) View.VISIBLE else View.GONE
    }

    private fun getGamepadStatusText(): String {
        return when (inputMethod) {
            InputMethod.GAMEPAD -> {
                val name = detectedGamepad?.let { GamepadManager.getGamepadName(it) } ?: "Gamepad"
                getString(R.string.status_gamepad_connected_name, name)
            }
            InputMethod.KEYBOARD_MOUSE -> getString(R.string.status_keyboard_mouse)
            InputMethod.UNKNOWN -> {
                if (isBluetoothScanning) getString(R.string.status_bt_scanning)
                else getString(R.string.status_gamepad_missing)
            }
        }
    }

    private fun getCalibrationStatusText(): String {
        if (inputMethod != InputMethod.GAMEPAD) {
            return getString(R.string.status_calibration_skip)
        }
        val buttons = listOf("A", "B", "X", "Y", "Start", "Select")
        return if (calibrationStep >= buttons.size) {
            getString(R.string.status_calibration_complete)
        } else {
            getString(R.string.status_calibration_press, buttons[calibrationStep])
        }
    }

    private fun handleAction() {
        when (step) {
            0 -> {
                if (inputMethod == InputMethod.UNKNOWN) {
                    startBluetoothScan()
                } else {
                    Toast.makeText(this, R.string.status_gamepad_connected, Toast.LENGTH_SHORT).show()
                }
            }
            2 -> showLicenseDialog()
            5 -> openWifiSettings()
            6 -> {
                if (!applyMaxRefreshRate()) openDisplaySettings()
            }
            7 -> updateStep()
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
            recreate()
        }
    }

    private fun showLicenseDialog() {
        val licenses = listOf(
            getString(R.string.license_console_launcher),
            getString(R.string.license_retroarch),
            getString(R.string.license_emulationstation),
            getString(R.string.license_kodi),
            getString(R.string.license_tvbro)
        )

        AlertDialog.Builder(this, R.style.Theme_PulsarSetup_Dialog)
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

    private fun startBluetoothScan() {
        val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        val btAdapter = btManager?.adapter
        if (btAdapter == null || !btAdapter.isEnabled) {
            Toast.makeText(this, R.string.toast_bt_disabled, Toast.LENGTH_LONG).show()
            openBluetoothSettings()
            return
        }

        isBluetoothScanning = true
        updateStep()

        btScanner = btAdapter.bluetoothLeScanner
        btScanner?.startScan(btScanCallback)

        handler.postDelayed({
            if (isBluetoothScanning) {
                btScanner?.stopScan(btScanCallback)
                isBluetoothScanning = false
                if (inputMethod == InputMethod.UNKNOWN) {
                    Toast.makeText(this, R.string.toast_bt_no_gamepad_found, Toast.LENGTH_LONG).show()
                }
                updateStep()
            }
        }, 10000L)
    }

    private val btScanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val device = result.device
            val name = device.name ?: return
            val address = device.address

            if (knownBtGamepads.contains(address)) return

            Log.i(TAG, "BT device found: $name ($address)")
            knownBtGamepads.add(address)

            val deviceClass = device.bluetoothClass?.majorDeviceClass
            if (deviceClass == android.bluetooth.BluetoothClass.Device.Major.PERIPHERAL ||
                deviceClass == android.bluetooth.BluetoothClass.Device.Major.AUDIO_VIDEO) {
                Log.i(TAG, "Potential gamepad: $name")
                handler.post {
                    Toast.makeText(this@SetupActivity,
                        getString(R.string.toast_bt_gamepad_found, name),
                        Toast.LENGTH_SHORT).show()
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            Log.e(TAG, "BT scan failed: $errorCode")
            isBluetoothScanning = false
            handler.post { updateStep() }
        }
    }

    fun onGamepadButtonPressed(keyCode: Int) {
        if (step != 4 || inputMethod != InputMethod.GAMEPAD) return

        val expectedKeyCodes = listOf(
            KeyEvent.KEYCODE_BUTTON_A,
            KeyEvent.KEYCODE_BUTTON_B,
            KeyEvent.KEYCODE_BUTTON_X,
            KeyEvent.KEYCODE_BUTTON_Y,
            KeyEvent.KEYCODE_BUTTON_START,
            KeyEvent.KEYCODE_BUTTON_SELECT
        )

        if (calibrationStep < expectedKeyCodes.size && keyCode == expectedKeyCodes[calibrationStep]) {
            calibrationStep++
            updateStep()

            if (calibrationStep >= expectedKeyCodes.size) {
                Toast.makeText(this, R.string.toast_calibration_complete, Toast.LENGTH_SHORT).show()
            }
        }
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

    /**
     * Gamepad navigation:
     * - A / DPAD_CENTER / ENTER = Next step
     * - B / BACK = Previous step (NOT skip!)
     * - DPAD_LEFT = Previous step
     * - DPAD_RIGHT = Action button (BT scan, open settings, etc.)
     */
    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Calibration step: capture button presses
        if (step == 4 && inputMethod == InputMethod.GAMEPAD) {
            onGamepadButtonPressed(keyCode)
            return true
        }

        when (keyCode) {
            // A button / D-pad center / Enter = NEXT
            KeyEvent.KEYCODE_BUTTON_A,
            KeyEvent.KEYCODE_DPAD_CENTER,
            KeyEvent.KEYCODE_ENTER -> {
                btnNext.performClick()
                return true
            }
            // B button / Back = PREVIOUS (go back one step, NOT skip all!)
            KeyEvent.KEYCODE_BUTTON_B,
            KeyEvent.KEYCODE_BACK -> {
                if (btnPrev.visibility == View.VISIBLE) {
                    btnPrev.performClick()
                }
                return true
            }
            // D-pad Left = PREVIOUS
            KeyEvent.KEYCODE_DPAD_LEFT -> {
                if (btnPrev.visibility == View.VISIBLE) {
                    btnPrev.performClick()
                }
                return true
            }
            // D-pad Right = ACTION (BT scan, open settings, etc.)
            KeyEvent.KEYCODE_DPAD_RIGHT -> {
                if (btnAction.visibility == View.VISIBLE) {
                    btnAction.performClick()
                }
                return true
            }
            // D-pad Up/Down = consume (prevent scrolling)
            KeyEvent.KEYCODE_DPAD_UP,
            KeyEvent.KEYCODE_DPAD_DOWN -> {
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onResume() {
        super.onResume()
        detectInputMethod()
        updateStep()
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(usbReceiver)
            unregisterReceiver(btReceiver)
        } catch (e: Exception) {
            // Receivers may not be registered
        }
        btScanner?.stopScan(btScanCallback)
    }
}
