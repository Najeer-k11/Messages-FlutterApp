package com.msgs.ndev.app

import android.annotation.SuppressLint
import android.content.Context
import android.os.Build

/**
 * Reads the system's Material You (wallpaper) colours for Flutter. Replaces the `dynamic_color`
 * plugin, which only exposed the legacy scheme and dropped every `surfaceContainer*` role.
 *
 * Returns, for Android 12+:
 *  - `palettes`: the five system tonal palettes (accent1-3, neutral1-2), each as 13 ARGB ints in
 *    Material tone order 0, 10, 20, ... 90, 95, 99, 100. Android's shade N is tone (1000 - N) / 10,
 *    with shade 10 being tone 99 and shade 50 tone 95.
 *  - `roles` (Android 14+ only): the exact system colour roles, per brightness, keyed by the
 *    Android resource name without the `system_` prefix and `_light` / `_dark` suffix. Roles that
 *    a given platform version does not define are simply absent; Dart derives them from the
 *    palettes instead.
 *
 * Names are resolved at runtime with [android.content.res.Resources.getIdentifier] so the same
 * code works across API levels, where newer roles (for example `inverse_surface`) are missing.
 */
object MaterialYouColors {
    /** Android shade for each Material tone in TonalPalette.commonTones order. */
    private val SHADES = intArrayOf(1000, 900, 800, 700, 600, 500, 400, 300, 200, 100, 50, 10, 0)

    private val PALETTES = listOf("accent1", "accent2", "accent3", "neutral1", "neutral2")

    /** Roles with `_light` and `_dark` variants. */
    private val ROLES = listOf(
        "primary", "on_primary", "primary_container", "on_primary_container", "inverse_primary",
        "secondary", "on_secondary", "secondary_container", "on_secondary_container",
        "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container",
        "error", "on_error", "error_container", "on_error_container",
        "surface", "on_surface", "on_surface_variant", "surface_dim", "surface_bright",
        "surface_container_lowest", "surface_container_low", "surface_container",
        "surface_container_high", "surface_container_highest",
        "outline", "outline_variant", "inverse_surface", "inverse_on_surface",
        "scrim", "shadow", "surface_tint",
    )

    /** Fixed roles are the same in light and dark. */
    private val FIXED_ROLES = listOf(
        "primary_fixed", "primary_fixed_dim", "on_primary_fixed", "on_primary_fixed_variant",
        "secondary_fixed", "secondary_fixed_dim", "on_secondary_fixed", "on_secondary_fixed_variant",
        "tertiary_fixed", "tertiary_fixed_dim", "on_tertiary_fixed", "on_tertiary_fixed_variant",
    )

    fun read(context: Context): Map<String, Any>? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return null

        val palettes = PALETTES.associateWith { name ->
            SHADES.map { shade -> color(context, "system_${name}_$shade") ?: return null }
        }
        val result = mutableMapOf<String, Any>("palettes" to palettes)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val fixed = FIXED_ROLES.mapNotNull { r -> color(context, "system_$r")?.let { r to it } }.toMap()
            fun rolesFor(suffix: String): Map<String, Int> =
                ROLES.mapNotNull { r -> color(context, "system_${r}_$suffix")?.let { r to it } }.toMap() + fixed
            result["roles"] = mapOf("light" to rolesFor("light"), "dark" to rolesFor("dark"))
        }
        return result
    }

    @SuppressLint("DiscouragedApi")
    private fun color(context: Context, name: String): Int? {
        val id = context.resources.getIdentifier(name, "color", "android")
        return if (id == 0) null else context.getColor(id)
    }
}
