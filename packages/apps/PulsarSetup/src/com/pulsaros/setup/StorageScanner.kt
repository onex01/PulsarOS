/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.content.Context
import android.os.Environment
import android.os.storage.StorageManager
import android.util.Log
import java.io.File

object StorageScanner {
    private const val TAG = "PulsarOS.Storage"

    data class StorageInfo(
        val path: String,
        val hasPulsarOS: Boolean,
        val hasRoms: Boolean,
        val totalBytes: Long,
        val freeBytes: Long
    )

    fun scanAll(context: Context): List<StorageInfo> {
        val sm = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
        val volumes = sm.storageVolumes
        Log.i(TAG, "Scanning ${volumes.size} storage volumes")

        return volumes.mapNotNull { vol ->
            val dir = try {
                @Suppress("DEPRECATION")
                vol.javaClass.getMethod("getPathFile").invoke(vol) as? File
            } catch (e: Exception) { null } ?: return@mapNotNull null

            if (!dir.exists()) return@mapNotNull null

            val pulsarDir = File(dir, "PulsarOS")
            StorageInfo(
                path = dir.absolutePath,
                hasPulsarOS = pulsarDir.exists(),
                hasRoms = File(pulsarDir, "roms").exists(),
                totalBytes = dir.totalSpace,
                freeBytes = dir.freeSpace
            ).also {
                Log.i(TAG, "Volume ${it.path}: pulsarOS=${it.hasPulsarOS}, roms=${it.hasRoms}")
            }
        }
    }
}