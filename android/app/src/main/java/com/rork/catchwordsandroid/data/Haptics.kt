package com.rork.catchwordsandroid.data

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * The iOS app's haptic vocabulary (Services/Haptics.swift) on Android: short composed primitives where the
 * device supports them (API 30+, a proper LRA motor), predefined clicks otherwise, and silence on a device
 * without a vibrator. Every pattern keeps the iOS timing so a correct answer or a landing feels the same.
 */
object Haptics {
    private var vibrator: Vibrator? = null

    fun init(context: Context) {
        vibrator = if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private val v: Vibrator? get() = vibrator?.takeIf { it.hasVibrator() }

    private fun supports(vararg ids: Int): Boolean =
        Build.VERSION.SDK_INT >= 30 && v?.areAllPrimitivesSupported(*ids) == true

    /** One composed pattern: (primitive, scale 0–1, delay ms since the previous one). */
    private fun compose(vararg steps: Triple<Int, Float, Int>): Boolean {
        if (Build.VERSION.SDK_INT < 30) return false
        val ids = steps.map { it.first }.distinct().toIntArray()
        if (!supports(*ids)) return false
        val c = VibrationEffect.startComposition()
        steps.forEach { (id, scale, delay) -> c.addPrimitive(id, scale.coerceIn(0f, 1f), delay) }
        runCatching { v?.vibrate(c.compose()) }
        return true
    }

    private fun predefined(effect: Int) {
        if (Build.VERSION.SDK_INT >= 29) runCatching { v?.vibrate(VibrationEffect.createPredefined(effect)) }
    }

    /** A finger going down on a button (iOS light impact 0.6). */
    fun press() {
        if (!compose(Triple(VibrationEffect.Composition.PRIMITIVE_TICK, 0.55f, 0))) predefined(VibrationEffect.EFFECT_TICK)
    }

    /** A picker or a page settling on a new value (UISelectionFeedbackGenerator). */
    fun selection() {
        if (!compose(Triple(VibrationEffect.Composition.PRIMITIVE_TICK, 0.4f, 0))) predefined(VibrationEffect.EFFECT_TICK)
    }

    /** A soft pop: tabs and the word page opening/closing (SoundService.pon). */
    fun pon(open: Boolean) {
        val s = if (open) 0.6f else 0.45f
        if (!compose(Triple(VibrationEffect.Composition.PRIMITIVE_CLICK, s, 0))) predefined(VibrationEffect.EFFECT_CLICK)
    }

    fun impact(strong: Boolean = false) {
        if (!compose(Triple(VibrationEffect.Composition.PRIMITIVE_CLICK, if (strong) 1f else 0.7f, 0))) {
            predefined(if (strong) VibrationEffect.EFFECT_HEAVY_CLICK else VibrationEffect.EFFECT_CLICK)
        }
    }

    /** Correct answer: a light tap, the ✓ popping in at 100 ms, a bright tail at 190 ms. */
    fun correct() {
        val ok = compose(
            Triple(VibrationEffect.Composition.PRIMITIVE_TICK, 0.5f, 0),
            Triple(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.85f, 90),
            Triple(VibrationEffect.Composition.PRIMITIVE_TICK, 0.35f, 80),
        )
        if (!ok) predefined(VibrationEffect.EFFECT_DOUBLE_CLICK)
    }

    /** Wrong answer: two dull knocks and a short rumble, timed with the choices' shake. */
    fun wrong() {
        val ok = compose(
            Triple(VibrationEffect.Composition.PRIMITIVE_THUD, 0.9f, 0),
            Triple(VibrationEffect.Composition.PRIMITIVE_THUD, 0.6f, 110),
        )
        if (!ok) {
            runCatching {
                v?.vibrate(VibrationEffect.createWaveform(longArrayOf(0, 30, 90, 24, 20, 120), intArrayOf(0, 230, 0, 150, 0, 70), -1))
            }
        }
    }

    /** A sticker landing: thump, bounce, settle (0 / 160 / 270 ms). */
    fun land() {
        val ok = compose(
            Triple(VibrationEffect.Composition.PRIMITIVE_CLICK, 1f, 0),
            Triple(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.55f, 150),
            Triple(VibrationEffect.Composition.PRIMITIVE_TICK, 0.3f, 100),
        )
        if (!ok) predefined(VibrationEffect.EFFECT_HEAVY_CLICK)
    }

    /** A round finished well. */
    fun success() {
        val ok = compose(
            Triple(VibrationEffect.Composition.PRIMITIVE_QUICK_RISE, 0.6f, 0),
            Triple(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.9f, 40),
        )
        if (!ok) predefined(VibrationEffect.EFFECT_DOUBLE_CLICK)
    }
}
