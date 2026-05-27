/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.app.AlertDialog
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity

class LicenseWarningActivity : AppCompatActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val appName = intent.getStringExtra("app_name") ?: "This app"
        val license = intent.getStringExtra("license") ?: "GPL"

        AlertDialog.Builder(this)
            .setTitle("Лицензионное уведомление")
            .setMessage("$appName распространяется под лицензией $license. " +
                "Модификации исходного кода должны быть опубликованы. " +
                "Подробнее: docs/LICENSE-STRATEGY.md")
            .setPositiveButton("Принять") { _, _ -> finish() }
            .setNegativeButton("Отмена") { _, _ -> finish() }
            .setCancelable(false)
            .show()
    }
}