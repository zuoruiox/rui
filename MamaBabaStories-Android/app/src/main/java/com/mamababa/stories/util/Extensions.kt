package com.mamababa.stories.util

import android.content.Context
import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.delay
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 通用扩展函数
 */

// ========== Context 扩展 ==========
fun Context.showToast(msg: String, duration: Int = Toast.LENGTH_SHORT) {
    Toast.makeText(this, msg, duration).show()
}

fun Context.dp2px(dp: Float): Float = dp * resources.displayMetrics.density
fun Context.px2dp(px: Float): Float = px / resources.displayMetrics.density

// ========== Long 时间扩展 ==========
fun Long.formatDuration(): String {
    val totalSec = this / 1000
    val min = totalSec / 60
    val sec = totalSec % 60
    return String.format(Locale.CHINA, "%d:%02d", min, sec)
}

fun Long.formatDurationSec(): String {
    val min = this / 60
    val sec = this % 60
    return String.format(Locale.CHINA, "%d:%02d", min, sec)
}

fun Long.formatDate(pattern: String = "yyyy-MM-dd"): String {
    return SimpleDateFormat(pattern, Locale.CHINA).format(Date(this))
}

fun Long.formatDateTime(): String {
    return SimpleDateFormat("yyyy-MM-dd HH:mm", Locale.CHINA).format(Date(this))
}

// ========== Int 扩展 ==========
val Int.dp: Float get() = this.toFloat()

// ========== String 扩展 ==========
fun String?.orDefault(default: String = ""): String = this ?: default

fun String.isPhoneNumber(): Boolean =
    matches(Regex("^1[3-9]\\d{9}$"))

fun String.isVerificationCode(): Boolean =
    matches(Regex("^\\d{4,6}$"))

// ========== File 扩展 ==========
fun File.createIfNotExists(): File {
    if (!exists()) {
        parentFile?.mkdirs()
        createNewFile()
    }
    return this
}

fun File.safeDelete() {
    if (exists()) delete()
}

// ========== Modifier 扩展 ==========
fun Modifier.alpha(alpha: Float): Modifier = this.graphicsLayer { this.alpha = alpha }

fun Modifier.fadingEdge(
    color: Color = Color.Black,
    isVertical: Boolean = true
): Modifier = this.drawWithContent {
    drawContent()
    val brush = if (isVertical) {
        Brush.verticalGradient(
            0f to color,
            0.05f to Color.Transparent,
            0.95f to Color.Transparent,
            1f to color
        )
    } else {
        Brush.horizontalGradient(
            0f to color,
            0.05f to Color.Transparent,
            0.95f to Color.Transparent,
            1f to color
        )
    }
    drawRect(brush = brush)
}

// ========== LazyList 扩展 ==========
@Composable
fun LazyListState.isScrollingUp(): Boolean {
    var previousIndex = remember { firstVisibleItemIndex }
    var previousScrollOffset = remember { firstVisibleItemScrollOffset }
    return remember {
        derivedStateOf {
            if (firstVisibleItemIndex != previousIndex) {
                val scrollingUp = firstVisibleItemIndex < previousIndex
                previousIndex = firstVisibleItemIndex
                previousScrollOffset = firstVisibleItemScrollOffset
                scrollingUp
            } else {
                val scrollingUp = firstVisibleItemScrollOffset < previousScrollOffset
                previousScrollOffset = firstVisibleItemScrollOffset
                scrollingUp
            }
        }
    }.value
}

// ========== 协程/Compose 扩展 ==========
@Composable
fun DelayEffect(key: Any?, delayMs: Long, block: suspend () -> Unit) {
    LaunchedEffect(key) {
        delay(delayMs)
        block()
    }
}

// ========== 数字格式化 ==========
fun Long.formatPlayCount(): String = when {
    this >= 10000 -> String.format(Locale.CHINA, "%.1f万", this / 10000.0)
    this >= 1000 -> String.format(Locale.CHINA, "%.1fk", this / 1000.0)
    else -> this.toString()
}

// ========== 分享 Intent ==========
fun shareStoryIntent(context: Context, storyTitle: String): Intent {
    return Intent(Intent.ACTION_SEND).apply {
        type = "text/plain"
        putExtra(Intent.EXTRA_TEXT, "我在「爸爸妈妈讲故事」听到一个好故事：$storyTitle，快来听听吧！")
    }
}
