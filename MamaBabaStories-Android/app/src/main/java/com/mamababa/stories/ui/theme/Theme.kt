package com.mamababa.stories.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.unit.dp
import androidx.core.view.WindowCompat

// 圆角形状
val AppShapes = Shapes(
    extraSmall = androidx.compose.foundation.shape.RoundedCornerShape(4.dp),
    small = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
    extraLarge = androidx.compose.foundation.shape.RoundedCornerShape(32.dp)
)

private val LightColorScheme = lightColorScheme(
    primary = Primary,
    onPrimary = OnPrimary,
    primaryContainer = PrimaryLight,
    onPrimaryContainer = OnBackground,

    secondary = Secondary,
    onSecondary = OnSecondary,
    secondaryContainer = Secondary.copy(alpha = 0.3f),
    onSecondaryContainer = OnSecondary,

    tertiary = Tertiary,
    onTertiary = OnTertiary,
    tertiaryContainer = TertiaryLight,
    onTertiaryContainer = OnBackground,

    background = Background,
    onBackground = OnBackground,
    surface = Surface,
    onSurface = OnSurface,
    surfaceVariant = SurfaceVariant,
    onSurfaceVariant = OnBackground.copy(alpha = 0.7f),

    error = Error,
    onError = Color.White,
    errorContainer = Error.copy(alpha = 0.2f),
    onErrorContainer = Error,

    outline = Outline,
    outlineVariant = Divider,
    scrim = Color.Black.copy(alpha = 0.3f)
)

private val DarkColorScheme = darkColorScheme(
    primary = PrimaryLight,
    onPrimary = Color.Black,
    primaryContainer = PrimaryDark,
    onPrimaryContainer = Color.White,

    secondary = Secondary,
    onSecondary = Color.Black,
    secondaryContainer = SecondaryDark,
    onSecondaryContainer = Color.Black,

    tertiary = TertiaryLight,
    onTertiary = Color.Black,
    tertiaryContainer = Tertiary,
    onTertiaryContainer = Color.Black,

    background = Color(0xFF1A0F08),
    onBackground = Color(0xFFFFF1E0),
    surface = Color(0xFF2D1B0E),
    onSurface = Color(0xFFFFF1E0),
    surfaceVariant = Color(0xFF3E2723),
    onSurfaceVariant = Color(0xFFFFE0C0),

    error = Error,
    onError = Color.White,
    outline = Color(0xFF5D4037),
    outlineVariant = Color(0xFF4E342E)
)

@Composable
fun MamaBabaStoriesTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme
    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = Color.Transparent.toArgb()
            window.navigationBarColor = colorScheme.surface.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = !darkTheme
            WindowCompat.getInsetsController(window, view).isAppearanceLightNavigationBars = !darkTheme
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        shapes = AppShapes,
        content = content
    )
}

/**
 * 播放器专用深色主题
 */
@Composable
fun PlayerTheme(content: @Composable () -> Unit) {
    val playerColorScheme = darkColorScheme(
        primary = PlayerAccent,
        onPrimary = PlayerBackground,
        primaryContainer = PlayerSurface,
        onPrimaryContainer = Color.White,
        secondary = Secondary,
        onSecondary = PlayerBackground,
        background = PlayerBackground,
        onBackground = Color.White,
        surface = PlayerSurface,
        onSurface = Color.White,
        surfaceVariant = Color(0xFF4E342E),
        onSurfaceVariant = Color(0xFFFFE0C0),
        error = Error,
        onError = Color.White,
        outline = Color(0xFF6D4C41)
    )
    MaterialTheme(
        colorScheme = playerColorScheme,
        typography = Typography,
        shapes = AppShapes,
        content = content
    )
}
