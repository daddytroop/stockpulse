package app.stockpulse

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager

/// Switches the home-screen icon between the launcher aliases declared in
/// AndroidManifest.xml. Exactly one alias is enabled at any time.
object AppIcons {
    /// Icon name (as the Dart side knows it) to alias class.
    private val aliases = linkedMapOf(
        "classic" to "app.stockpulse.IconClassic",
        "neon" to "app.stockpulse.IconNeon",
        "gold" to "app.stockpulse.IconGold",
        "aurora" to "app.stockpulse.IconAurora",
        "sakura" to "app.stockpulse.IconSakura",
    )

    fun current(context: Context): String {
        val pm = context.packageManager
        for ((name, cls) in aliases) {
            val state = pm.getComponentEnabledSetting(ComponentName(context, cls))
            val enabled = when (state) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> name == "classic"
                else -> false
            }
            if (enabled) return name
        }
        return "classic"
    }

    /// Enables [name]'s alias and disables the others. Returns false for an
    /// unknown name.
    fun set(context: Context, name: String): Boolean {
        if (!aliases.containsKey(name)) return false
        val pm = context.packageManager
        // Enable the new one first, so there is never a moment without a
        // launcher entry.
        pm.setComponentEnabledSetting(
            ComponentName(context, aliases.getValue(name)),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
        for ((other, cls) in aliases) {
            if (other == name) continue
            pm.setComponentEnabledSetting(
                ComponentName(context, cls),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }
        return true
    }
}
