/*
 * Copyright (C) 2026 PulsarOS Project
 * SPDX-License-Identifier: MIT
 */
package com.pulsaros.setup

import android.bluetooth.BluetoothDevice
import android.util.Log
import android.view.InputDevice

object GamepadManager {

    private const val TAG = "PulsarOS.Gamepad"

    private data class GamepadEntry(
        val vendorId: Int,
        val productId: Int,
        val name: String
    )

    private val whitelist = listOf(
        // Nintendo
        GamepadEntry(0x057E, 0x2009, "Nintendo Switch Pro Controller"),
        GamepadEntry(0x057E, 0x2006, "Nintendo Switch Joy-Con (L)"),
        GamepadEntry(0x057E, 0x2007, "Nintendo Switch Joy-Con (R)"),
        GamepadEntry(0x057E, 0x1918, "Nintendo Switch Online NES Controller"),
        GamepadEntry(0x057E, 0x1917, "Nintendo Switch Online SNES Controller"),
        GamepadEntry(0x057E, 0x2017, "Nintendo Switch Online N64 Controller"),
        GamepadEntry(0x057E, 0x2019, "Nintendo Switch Online Mega Drive Controller"),

        // Sony
        GamepadEntry(0x054C, 0x0CE6, "Sony DualSense"),
        GamepadEntry(0x054C, 0x0DF2, "Sony DualSense Edge"),
        GamepadEntry(0x054C, 0x05C4, "Sony DualShock 4"),
        GamepadEntry(0x054C, 0x09CC, "Sony DualShock 4 (v2)"),

        // Microsoft
        GamepadEntry(0x045E, 0x0B12, "Xbox Series X/S Controller"),
        GamepadEntry(0x045E, 0x0B13, "Xbox Series X/S Controller (BT)"),
        GamepadEntry(0x045E, 0x02D1, "Xbox One Controller"),
        GamepadEntry(0x045E, 0x02DD, "Xbox One S Controller"),
        GamepadEntry(0x045E, 0x02E3, "Xbox One Elite Controller"),
        GamepadEntry(0x045E, 0x0B05, "Xbox Series X|S Elite Wireless Controller Series 2"),
        GamepadEntry(0x045E, 0x0B22, "Xbox Wireless Controller"),

        // 8BitDo
        GamepadEntry(0x2DC8, 0x6016, "8BitDo Ultimate"),
        GamepadEntry(0x2DC8, 0x6017, "8BitDo Ultimate 2C"),
        GamepadEntry(0x2DC8, 0x2004, "8BitDo Pro 2"),
        GamepadEntry(0x2DC8, 0x1101, "8BitDo SN30 Pro+"),
        GamepadEntry(0x2DC8, 0x1016, "8BitDo SN30 Pro"),
        GamepadEntry(0x2DC8, 0x6000, "8BitDo Zero 2"),
        GamepadEntry(0x2DC8, 0x6010, "8BitDo Lite"),
        GamepadEntry(0x2DC8, 0x6012, "8BitDo Pro"),
        GamepadEntry(0x2DC8, 0x6018, "8BitDo Ultimate C"),

        // GameSir
        GamepadEntry(0x3537, 0x1004, "GameSir T4 Pro"),
        GamepadEntry(0x3537, 0x1006, "GameSir T4 Mini"),
        GamepadEntry(0x3537, 0x1008, "GameSir T7"),

        // Razer
        GamepadEntry(0x1532, 0x0A00, "Razer Wolverine V2"),
        GamepadEntry(0x1532, 0x0A29, "Razer Kishi"),

        // SteelSeries
        GamepadEntry(0x1038, 0x1130, "SteelSeries Stratus+"),
    )

    fun isWhitelisted(device: InputDevice): Boolean {
        val vendorId = device.vendorId
        val productId = device.productId
        return whitelist.any { it.vendorId == vendorId && it.productId == productId }
    }

    fun isWhitelistedByVidPid(vendorId: Int, productId: Int): Boolean {
        return whitelist.any { it.vendorId == vendorId && it.productId == productId }
    }

    fun getGamepadName(vendorId: Int, productId: Int): String {
        return whitelist.find { it.vendorId == vendorId && it.productId == productId }?.name
            ?: "Unknown Gamepad"
    }

    fun getGamepadName(device: InputDevice): String {
        return getGamepadName(device.vendorId, device.productId)
    }

    fun getGamepads(): List<InputDevice> {
        return InputDevice.getDeviceIds().toList().mapNotNull { id ->
            InputDevice.getDevice(id)
        }.filter { device ->
            !device.isVirtual && (
                device.supportsSource(InputDevice.SOURCE_GAMEPAD) ||
                device.supportsSource(InputDevice.SOURCE_JOYSTICK) ||
                device.supportsSource(InputDevice.SOURCE_DPAD)
            )
        }
    }

    fun getWhitelistedGamepads(): List<InputDevice> {
        return getGamepads().filter { isWhitelisted(it) }
    }

    fun getGamepadNameFromBluetooth(address: String): String {
        return try {
            val clazz = Class.forName("android.bluetooth.BluetoothDevice")
            val method = clazz.getMethod("getAlias")
            "Bluetooth Gamepad"
        } catch (e: Exception) {
            "Bluetooth Gamepad"
        }
    }

    fun isGamepadDevice(device: InputDevice): Boolean {
        return device.supportsSource(InputDevice.SOURCE_GAMEPAD) ||
            device.supportsSource(InputDevice.SOURCE_JOYSTICK)
    }

    fun hasKeyboardOrMouse(): Boolean {
        return InputDevice.getDeviceIds().any { id ->
            val device = InputDevice.getDevice(id) ?: return@any false
            !device.isVirtual && device.supportsSource(InputDevice.SOURCE_KEYBOARD)
        }
    }
}
