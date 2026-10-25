package com.rork.catchwordsandroid.ui.components

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.keyframes
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.graphicsLayer
import com.rork.catchwordsandroid.data.Haptics
import kotlin.math.PI
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import com.rork.catchwordsandroid.data.AppGraph
import com.rork.catchwordsandroid.data.Category
import com.rork.catchwordsandroid.data.ReviewState
import com.rork.catchwordsandroid.data.Sticker
import com.rork.catchwordsandroid.ui.theme.CW

/** The app's airy sky background: soft gradient with two blurred light pools. */
@Composable
fun AppBackground(modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit = {}) {
    Box(modifier.fillMaxSize().background(Brush.verticalGradient(listOf(CW.background, Color(0xFFF1F7FF), CW.backgroundDeep)))) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(
                Brush.radialGradient(listOf(CW.accent.copy(alpha = 0.75f), Color.Transparent), center = Offset(size.width * 0.95f, size.height * 0.05f), radius = size.width * 0.8f),
                radius = size.width * 0.8f, center = Offset(size.width * 0.95f, size.height * 0.05f),
            )
            drawCircle(
                Brush.radialGradient(listOf(Color(0xFFE4F6FF).copy(alpha = 0.8f), Color.Transparent), center = Offset(0f, size.height * 0.75f), radius = size.width * 0.7f),
                radius = size.width * 0.7f, center = Offset(0f, size.height * 0.75f),
            )
        }
        content()
    }
}

/** Press-to-shrink feedback used on every tappable surface. */
@Composable
fun Modifier.pressable(
    enabled: Boolean = true,
    haptic: Boolean = true,
    pressedScale: Float = 0.96f,
    role: Role = Role.Button,
    onClick: () -> Unit,
): Modifier {
    val source = remember { MutableInteractionSource() }
    val pressed by source.collectIsPressedAsState()
    // iOS PressableStyle: spring(response 0.28, damping 0.62); the light tap lands as the finger goes down.
    val s by animateFloatAsState(if (pressed) pressedScale else 1f, iosSpring(0.28f, 0.62f), label = "press")
    androidx.compose.runtime.LaunchedEffect(pressed) { if (pressed && haptic && enabled) Haptics.press() }
    return this
        .graphicsLayer { scaleX = s; scaleY = s }
        .clickable(interactionSource = source, indication = null, enabled = enabled, role = role, onClick = onClick)
}

@Composable
fun PrimaryButton(
    title: String,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    loading: Boolean = false,
    sheen: Boolean = false,
    onClick: () -> Unit,
) {
    val shape = RoundedCornerShape(16.dp)
    val alpha by animateFloatAsState(if (enabled) 1f else 0.45f, tween(200), label = "enabled")
    Box(
        modifier
            .fillMaxWidth()
            .heightIn(min = 54.dp)
            .graphicsLayer { this.alpha = alpha }
            .shadow(if (enabled) 14.dp else 0.dp, shape, ambientColor = CW.primary.copy(alpha = 0.45f), spotColor = CW.primary.copy(alpha = 0.6f))
            .clip(shape)
            .background(CW.brandGradient)
            .then(if (sheen && enabled) Modifier.sheen() else Modifier)
            .pressable(enabled = enabled && !loading, onClick = onClick)
            .padding(horizontal = 20.dp, vertical = 14.dp),
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.animation.Crossfade(loading, animationSpec = tween(180), label = "loading") { busy ->
            if (busy) {
                CircularProgressIndicator(Modifier.size(22.dp), color = Color.White, strokeWidth = 2.5.dp)
            } else {
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.Center) {
                    if (icon != null) {
                        Icon(icon, null, tint = Color.White, modifier = Modifier.size(20.dp))
                        Spacer(Modifier.width(8.dp))
                    }
                    Text(title, color = Color.White, fontSize = 17.sp, fontWeight = FontWeight.SemiBold)
                }
            }
        }
    }
}

/** A soft white band sweeping across (1.1 s every 3.4 s), the iOS primary button's sheen. */
@Composable
fun Modifier.sheen(): Modifier {
    val t = rememberInfiniteTransition(label = "sheen")
    val p by t.animateFloat(
        0f, 1f,
        infiniteRepeatable(keyframes { durationMillis = 3400; 0f at 0; 0f at 2300 using FastOutSlowInEasing; 1f at 3400 }),
        label = "p",
    )
    return drawWithContent {
        drawContent()
        if (p <= 0f || p >= 1f) return@drawWithContent
        val band = size.width * 0.35f
        val x = -band + (size.width + band * 2) * p
        drawRect(
            Brush.linearGradient(
                listOf(Color.Transparent, Color.White.copy(alpha = 0.35f), Color.Transparent),
                start = Offset(x - band / 2, 0f), end = Offset(x + band / 2, size.height * 0.33f),
            ),
        )
    }
}

/** SwiftUI's spring(response:dampingFraction:) in Compose terms. */
fun <T> iosSpring(response: Float, damping: Float, visibilityThreshold: T? = null) =
    spring(dampingRatio = damping, stiffness = (2f * PI.toFloat() / response).let { it * it }, visibilityThreshold = visibilityThreshold)

/**
 * Rises and fades in once, [delayMs] after first composition (lists and cards appearing).
 * [enabled] false shows it in place at once (items scrolled into view later must not dance).
 */
@Composable
fun Modifier.appear(delayMs: Int = 0, enabled: Boolean = true, rise: Dp = 14.dp): Modifier {
    val p = remember { Animatable(if (enabled) 0f else 1f) }
    androidx.compose.runtime.LaunchedEffect(Unit) {
        if (p.value < 1f) {
            kotlinx.coroutines.delay(delayMs.toLong())
            p.animateTo(1f, iosSpring(0.5f, 0.86f))
        }
    }
    return graphicsLayer {
        alpha = p.value.coerceIn(0f, 1f)
        translationY = (1f - p.value) * rise.toPx()
    }
}

@Composable
fun SecondaryButton(title: String, modifier: Modifier = Modifier, icon: ImageVector? = null, tint: Color = CW.primaryInk, onClick: () -> Unit) {
    Row(
        modifier
            .heightIn(min = 48.dp)
            .clip(RoundedCornerShape(50))
            .background(CW.surface2)
            .pressable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, null, tint = tint, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
        }
        Text(title, color = tint, fontSize = 15.sp, fontWeight = FontWeight.SemiBold)
    }
}

/** White rounded card with a hairline border (settings groups, dex rooms). */
@Composable
fun SectionCard(modifier: Modifier = Modifier, padding: Dp = 16.dp, content: @Composable ColumnScope.() -> Unit) {
    Column(
        modifier
            .fillMaxWidth()
            .shadow(6.dp, RoundedCornerShape(24.dp), ambientColor = Color(0x14000000), spotColor = Color(0x14000000))
            .clip(RoundedCornerShape(24.dp))
            .background(CW.card)
            .border(1.dp, CW.border, RoundedCornerShape(24.dp))
            .padding(padding),
        content = content,
    )
}

@Composable
fun ScreenHeader(title: String, subtitle: String? = null, modifier: Modifier = Modifier) {
    Column(modifier) {
        Text(title, fontSize = 30.sp, fontWeight = FontWeight.Black, color = CW.foreground, letterSpacing = (-0.5).sp)
        if (subtitle != null) Text(subtitle, fontSize = 14.sp, color = CW.muted)
    }
}

/** A sticker's picture from its signed link; the category emoji while it loads or when there is none. */
@Composable
fun StickerImage(sticker: Sticker, modifier: Modifier = Modifier, contentScale: ContentScale = ContentScale.Fit, emojiSize: Int = 34) {
    val signed by AppGraph.dex.state.collectAsState()
    val url = sticker.heroPath?.let { signed.signed[it] }
    Box(modifier, contentAlignment = Alignment.Center) {
        if (url == null) {
            Text(Category.emoji(sticker.categoryKey), fontSize = emojiSize.sp)
        } else {
            AsyncImage(model = url, contentDescription = sticker.word?.headword, contentScale = contentScale, modifier = Modifier.fillMaxSize())
        }
    }
}

/** Memory % pill (srs.ts levels). */
@Composable
fun MemoryBadge(percent: Int, modifier: Modifier = Modifier) {
    val c = CW.memoryLevels[ReviewState.level(percent)]
    Row(
        modifier
            .shadow(3.dp, CircleShape)
            .clip(CircleShape)
            .background(CW.card.copy(alpha = 0.95f))
            .padding(horizontal = 7.dp, vertical = 3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(6.dp).clip(CircleShape).background(c))
        Spacer(Modifier.width(4.dp))
        Text("$percent%", fontSize = 11.sp, fontWeight = FontWeight.SemiBold, color = androidx.compose.ui.graphics.lerp(c, CW.foreground, 0.4f), style = androidx.compose.ui.text.TextStyle(fontFeatureSettings = "tnum"))
    }
}

/** The dark pill that shows a one-line notice over the screen. */
@Composable
fun Toast(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        color = Color.White,
        fontSize = 14.sp,
        fontWeight = FontWeight.Medium,
        textAlign = androidx.compose.ui.text.style.TextAlign.Center,
        modifier = modifier
            .padding(horizontal = 24.dp)
            .shadow(10.dp, RoundedCornerShape(22.dp))
            .clip(RoundedCornerShape(22.dp))
            .background(CW.toastInk.copy(alpha = 0.88f))
            .padding(horizontal = 16.dp, vertical = 10.dp),
    )
}

/** A toast that slides down from the top with a spring and fades away (iOS spring(0.35, 0.85)). */
@Composable
fun ToastHost(message: String?, modifier: Modifier = Modifier) {
    var last by remember { androidx.compose.runtime.mutableStateOf(message.orEmpty()) }
    if (message != null) last = message
    androidx.compose.animation.AnimatedVisibility(
        visible = message != null,
        enter = androidx.compose.animation.slideInVertically(iosSpring(0.35f, 0.85f)) { -it * 2 } + androidx.compose.animation.fadeIn(tween(160)),
        exit = androidx.compose.animation.fadeOut(tween(250)) + androidx.compose.animation.scaleOut(tween(250), targetScale = 0.96f),
        modifier = modifier,
    ) { Toast(last) }
}

/** Reading line under a headword: zhuyin by default, pinyin when chosen in settings. */
fun readingOf(zhuyin: String?, pinyin: String?): String {
    val z = zhuyin?.trim().orEmpty()
    val p = pinyin?.trim().orEmpty()
    return if (AppGraph.readingStyle == "pinyin") p.ifEmpty { z } else z.ifEmpty { p }
}

@Composable
fun Chip(text: String, modifier: Modifier = Modifier, selected: Boolean = false, onClick: (() -> Unit)? = null) {
    val bg by androidx.compose.animation.animateColorAsState(if (selected) CW.primary else CW.surface2, tween(200), label = "chip")
    val ink by androidx.compose.animation.animateColorAsState(if (selected) Color.White else CW.foreground, tween(200), label = "ink")
    Text(
        text,
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold,
        color = ink,
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(bg)
            .then(if (onClick != null) Modifier.pressable(onClick = onClick) else Modifier)
            .padding(horizontal = 14.dp, vertical = 8.dp),
    )
}
