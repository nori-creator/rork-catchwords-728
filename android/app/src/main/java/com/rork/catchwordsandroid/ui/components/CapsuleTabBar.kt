package com.rork.catchwordsandroid.ui.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.AutoAwesome
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Home
import androidx.compose.material.icons.automirrored.outlined.MenuBook
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.width
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.min
import com.rork.catchwordsandroid.data.AppGraph
import com.rork.catchwordsandroid.data.Haptics
import com.rork.catchwordsandroid.data.Speech
import kotlin.math.roundToInt
import androidx.compose.material.icons.outlined.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rork.catchwordsandroid.data.tr
import com.rork.catchwordsandroid.ui.theme.CW

enum class AppTab(val route: String, val icon: ImageVector, val filled: ImageVector) {
    HOME("home", Icons.Outlined.Home, Icons.Filled.Home),
    DEX("dex", Icons.AutoMirrored.Outlined.MenuBook, Icons.AutoMirrored.Filled.MenuBook),
    CAMERA("camera", Icons.Outlined.CameraAlt, Icons.Filled.CameraAlt),
    REVIEW("review", Icons.Outlined.AutoAwesome, Icons.Filled.AutoAwesome),
    SETTINGS("settings", Icons.Outlined.Settings, Icons.Filled.Settings);

    val title: String
        get() = when (this) {
            HOME -> tr("ホーム", "Home", "首頁")
            DEX -> tr("図鑑", "Dex", "圖鑑")
            CAMERA -> tr("カメラ", "Camera", "相機")
            REVIEW -> tr("復習", "Review", "複習")
            SETTINGS -> tr("設定", "Settings", "設定")
        }
}

/**
 * The floating capsule tab bar of the iOS app (MainTabView): a 58 dp capsule at most 400 dp wide, a soft
 * primary pill that springs between cells, a bounce on the newly picked icon, and the bubble "pon" with a tap.
 * Over the camera it turns to dark navy glass.
 */
@Composable
fun CapsuleTabBar(selected: AppTab?, dark: Boolean, onSelect: (AppTab) -> Unit, modifier: Modifier = Modifier) {
    val bg by animateColorAsState(if (dark) Color(0xF2131E37) else Color(0xF7FFFFFF), tween(250), label = "bg")
    val border by animateColorAsState(if (dark) Color(0x26FFFFFF) else CW.border, tween(250), label = "border")
    val tabs = AppTab.entries
    val index = tabs.indexOf(selected).coerceAtLeast(0)
    val pillX by animateFloatAsState(index.toFloat(), iosSpring(0.38f, 0.78f), label = "pill")
    val pillAlpha by animateFloatAsState(if (selected == null) 0f else 1f, tween(200), label = "pillA")

    BoxWithConstraints(modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
        val width = min(maxWidth * 0.92f, 400.dp)
        Box(
            Modifier
                .width(width)
                .height(58.dp)
                .shadow(16.dp, RoundedCornerShape(50), ambientColor = Color.Black.copy(alpha = if (dark) 0.3f else 0.10f), spotColor = Color.Black.copy(alpha = if (dark) 0.35f else 0.16f))
                .clip(RoundedCornerShape(50))
                .background(bg)
                .border(1.dp, border, RoundedCornerShape(50))
                .padding(4.dp),
        ) {
            val cell = (width - 8.dp) / tabs.size
            // The selected pill: primary at 14 % (cyan glow on the camera), sliding between cells.
            Box(
                Modifier
                    .offset { IntOffset((cell.toPx() * pillX).roundToInt(), 0) }
                    .width(cell)
                    .fillMaxHeight()
                    .graphicsLayer { alpha = pillAlpha }
                    .clip(RoundedCornerShape(50))
                    .background(if (dark) CW.cyan.copy(alpha = 0.16f) else CW.primary.copy(alpha = 0.12f)),
            )
            Row(Modifier.fillMaxSize()) {
                tabs.forEach { tab ->
                    TabCell(tab, tab == selected, dark, Modifier.width(cell).fillMaxHeight()) {
                        if (tab != selected) {
                            if (AppGraph.soundsOn) AppGraph.speech.play(Speech.Sfx.PON_OPEN, 0.55f)
                            Haptics.pon(open = true)
                        }
                        onSelect(tab)
                    }
                }
            }
        }
    }
}

@Composable
private fun TabCell(tab: AppTab, isOn: Boolean, dark: Boolean, modifier: Modifier, onClick: () -> Unit) {
    val ink by animateColorAsState(
        when {
            isOn -> if (dark) CW.cyan else CW.primary
            tab == AppTab.CAMERA -> if (dark) CW.cyan else CW.primary
            dark -> Color(0xB3FFFFFF)
            else -> CW.foreground.copy(alpha = 0.72f)
        },
        tween(200), label = "ink",
    )
    // The symbol bounce: a quick squash up and settle when the tab becomes current.
    val bounce = remember { Animatable(1f) }
    LaunchedEffect(isOn) {
        if (isOn) {
            bounce.snapTo(0.82f)
            bounce.animateTo(1f, spring(dampingRatio = 0.42f, stiffness = 520f))
        }
    }
    Box(
        modifier
            .pressable(pressedScale = 0.92f, haptic = false, role = Role.Tab, onClick = onClick)
            .semantics { contentDescription = tab.title },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                if (isOn) tab.filled else tab.icon, null, tint = ink,
                modifier = Modifier.size(22.dp).graphicsLayer { scaleX = bounce.value; scaleY = bounce.value; transformOrigin = TransformOrigin(0.5f, 1f) },
            )
            Spacer(Modifier.height(3.dp))
            Text(tab.title, fontSize = 10.sp, fontWeight = if (isOn) FontWeight.SemiBold else FontWeight.Medium, color = ink, maxLines = 1)
        }
    }
}
