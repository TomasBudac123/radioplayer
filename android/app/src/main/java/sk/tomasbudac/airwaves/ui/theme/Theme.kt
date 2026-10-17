package sk.tomasbudac.airwaves.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Neutrálna paleta zdieľaná s iOS (`design/tokens.json`). Dynamické farby (Material You)
 * zámerne nepoužívame – farbu do rozhrania prinášajú len logá rádií.
 */
@Immutable
data class AirwavesColors(
    val background: Color,
    val surface: Color,
    val surfaceMuted: Color,
    val border: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val accent: Color,
    val onAccent: Color,
    val danger: Color,
)

val LightAirwavesColors = AirwavesColors(
    background = Color(0xFFF6F6F7),
    surface = Color(0xFFFFFFFF),
    surfaceMuted = Color(0xFFEDEDEF),
    border = Color(0xFFE2E2E5),
    textPrimary = Color(0xFF17171A),
    textSecondary = Color(0xFF62626B),
    textTertiary = Color(0xFF9C9CA4),
    accent = Color(0xFF17171A),
    onAccent = Color(0xFFFFFFFF),
    danger = Color(0xFFB42318),
)

val DarkAirwavesColors = AirwavesColors(
    background = Color(0xFF0D0D0F),
    surface = Color(0xFF17171A),
    surfaceMuted = Color(0xFF222226),
    border = Color(0xFF2D2D32),
    textPrimary = Color(0xFFF3F3F5),
    textSecondary = Color(0xFFA3A3AB),
    textTertiary = Color(0xFF6C6C74),
    accent = Color(0xFFF3F3F5),
    onAccent = Color(0xFF0D0D0F),
    danger = Color(0xFFF97066),
)

object Spacing {
    val xxs = 4.dp
    val xs = 8.dp
    val s = 12.dp
    val m = 16.dp
    val l = 24.dp
    val xl = 32.dp
}

object Radius {
    val small = 8.dp
    val control = 12.dp
    val card = 16.dp
    val tile = 20.dp
    val artworkLarge = 28.dp
}

val LocalAirwavesColors = staticCompositionLocalOf { LightAirwavesColors }

object AirwavesTheme {
    val colors: AirwavesColors
        @Composable get() = LocalAirwavesColors.current
}

@Composable
fun AirwavesTheme(darkTheme: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    val colors = if (darkTheme) DarkAirwavesColors else LightAirwavesColors
    val scheme = (if (darkTheme) darkColorScheme() else lightColorScheme()).copy(
        primary = colors.accent,
        onPrimary = colors.onAccent,
        primaryContainer = colors.surfaceMuted,
        onPrimaryContainer = colors.textPrimary,
        secondary = colors.textSecondary,
        onSecondary = colors.onAccent,
        secondaryContainer = colors.surfaceMuted,
        onSecondaryContainer = colors.textPrimary,
        tertiary = colors.textSecondary,
        background = colors.background,
        onBackground = colors.textPrimary,
        surface = colors.background,
        onSurface = colors.textPrimary,
        surfaceVariant = colors.surfaceMuted,
        onSurfaceVariant = colors.textSecondary,
        surfaceTint = Color.Transparent,
        surfaceBright = colors.surface,
        surfaceDim = colors.background,
        surfaceContainerLowest = colors.surface,
        surfaceContainerLow = colors.surface,
        surfaceContainer = colors.surface,
        surfaceContainerHigh = colors.surface,
        surfaceContainerHighest = colors.surfaceMuted,
        inverseSurface = colors.textPrimary,
        inverseOnSurface = colors.background,
        outline = colors.border,
        outlineVariant = colors.border,
        error = colors.danger,
    )
    val base = Typography()
    val typography = base.copy(
        headlineLarge = base.headlineLarge.copy(fontWeight = FontWeight.Bold, fontSize = 32.sp, letterSpacing = (-0.5).sp),
        titleLarge = base.titleLarge.copy(fontWeight = FontWeight.Bold),
        titleMedium = base.titleMedium.copy(fontWeight = FontWeight.SemiBold),
        labelLarge = TextStyle(fontWeight = FontWeight.SemiBold, fontSize = 15.sp),
    )
    MaterialTheme(
        colorScheme = scheme,
        typography = typography,
        shapes = Shapes(
            small = RoundedCornerShape(Radius.small),
            medium = RoundedCornerShape(Radius.control),
            large = RoundedCornerShape(Radius.card),
            extraLarge = RoundedCornerShape(Radius.artworkLarge),
        ),
    ) {
        androidx.compose.runtime.CompositionLocalProvider(LocalAirwavesColors provides colors, content = content)
    }
}
