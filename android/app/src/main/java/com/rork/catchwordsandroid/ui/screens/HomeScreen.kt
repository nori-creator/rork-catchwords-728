package com.rork.catchwordsandroid.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.layout.wrapContentSize
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.lerp
import com.rork.catchwordsandroid.data.AppGraph
import com.rork.catchwordsandroid.data.Haptics
import com.rork.catchwordsandroid.data.Speech
import com.rork.catchwordsandroid.ui.components.appear
import kotlin.math.abs
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Person
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import coil3.compose.AsyncImage
import com.rork.catchwordsandroid.data.L10n
import com.rork.catchwordsandroid.data.ReaderLanguage
import com.rork.catchwordsandroid.data.Sticker
import com.rork.catchwordsandroid.data.tr
import com.rork.catchwordsandroid.ui.DexViewModel
import com.rork.catchwordsandroid.ui.components.PrimaryButton
import com.rork.catchwordsandroid.ui.components.StickerImage
import com.rork.catchwordsandroid.ui.components.pressable
import com.rork.catchwordsandroid.ui.theme.CW
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle

/** Home: the bookshelf of past months and this month's paper album, one page per day. */
@Composable
fun HomeScreen(onOpenWord: (String) -> Unit, onCamera: () -> Unit, vm: DexViewModel = viewModel()) {
    val state by vm.state.collectAsStateWithLifecycle()
    val profile by vm.profile.collectAsStateWithLifecycle()
    val zone = remember { ZoneId.systemDefault() }
    val today = remember { LocalDate.now(zone) }
    val month = YearMonth.from(today)

    val byDay = remember(state.stickers) {
        state.stickers.groupBy { Instant.ofEpochMilli(it.takenAtMs).atZone(zone).toLocalDate() }
    }
    val days = remember(byDay) {
        (byDay.keys.filter { YearMonth.from(it) == month } + today).distinct().sorted()
    }
    val pastMonths = remember(byDay) {
        byDay.keys.map { YearMonth.from(it) }.filter { it < month }.distinct().sortedDescending()
            .map { ym -> ym to byDay.filterKeys { YearMonth.from(it) == ym }.values.sumOf { it.size } }
    }

    Box(Modifier.fillMaxSize().background(Brush.verticalGradient(listOf(Color(0xFFFBF8F3), Color(0xFFF3EDE3))))) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).statusBarsPadding().padding(bottom = 96.dp)) {
            Row(Modifier.padding(horizontal = 20.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    Modifier.size(40.dp).shadow(4.dp, CircleShape).clip(CircleShape).background(CW.surface2).border(2.dp, Color.White, CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    if (profile.avatarUrl != null) {
                        AsyncImage(profile.avatarUrl, null, contentScale = ContentScale.Crop, modifier = Modifier.fillMaxSize())
                    } else {
                        Icon(Icons.Outlined.Person, null, tint = CW.muted)
                    }
                }
                Spacer(Modifier.width(10.dp))
                Text(profile.displayName.ifBlank { "CatchWords" }, fontSize = 18.sp, fontWeight = FontWeight.Medium, color = CW.muted)
            }

            Bookshelf(pastMonths, Modifier.padding(horizontal = 14.dp))

            Row(Modifier.padding(start = 20.dp, end = 20.dp, top = 22.dp, bottom = 8.dp), verticalAlignment = Alignment.Bottom) {
                Text(
                    tr("${month.monthValue}月のアルバム", "${month.month.getDisplayName(TextStyle.FULL, L10n.locale)} album", "${month.monthValue}月的相簿"),
                    fontSize = 20.sp, fontWeight = FontWeight.ExtraBold, color = CW.foreground, modifier = Modifier.weight(1f),
                )
                Text(tr("横にスワイプでページをめくる", "Swipe to turn pages", "左右滑動翻頁"), fontSize = 11.sp, color = CW.muted)
            }

            val pager = rememberPagerState(initialPage = (days.size - 1).coerceAtLeast(0)) { days.size }
            // A page lands with a soft tap and a paper rustle, like turning a real album.
            var settledOnce by remember { mutableStateOf(false) }
            LaunchedEffect(pager.settledPage) {
                if (settledOnce) {
                    Haptics.selection()
                    if (AppGraph.soundsOn) AppGraph.speech.play(Speech.Sfx.TICK, 0.25f)
                }
                settledOnce = true
            }
            HorizontalPager(state = pager, modifier = Modifier.fillMaxWidth().height(560.dp), contentPadding = androidx.compose.foundation.layout.PaddingValues(horizontal = 12.dp), pageSpacing = 8.dp) { page ->
                val day = days[page]
                AlbumPage(
                    day, byDay[day].orEmpty(), isToday = day == today, onOpenWord = onOpenWord, onCamera = onCamera,
                    modifier = Modifier.graphicsLayer {
                        // Pages swing on their spine edge as they turn.
                        val off = ((pager.currentPage - page) + pager.currentPageOffsetFraction).coerceIn(-1f, 1f)
                        cameraDistance = 14f * density
                        transformOrigin = TransformOrigin(if (off > 0f) 1f else 0f, 0.5f)
                        rotationY = off * -18f
                        val k = 1f - abs(off) * 0.08f
                        scaleX = k; scaleY = k
                        alpha = 1f - abs(off) * 0.35f
                    },
                )
            }
        }
    }
}

@Composable
private fun Bookshelf(months: List<Pair<YearMonth, Int>>, modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxWidth()
            .height(180.dp)
            .shadow(10.dp, RoundedCornerShape(10.dp))
            .clip(RoundedCornerShape(10.dp))
            .background(Brush.verticalGradient(listOf(CW.woodLight, Color(0xFF9A6236))))
            .padding(12.dp),
    ) {
        Box(Modifier.fillMaxSize().clip(RoundedCornerShape(4.dp)).background(Brush.verticalGradient(listOf(Color(0xFF4A2C17), CW.wood)))) {
            if (months.isEmpty()) {
                Text(
                    tr("先月までの本がここに並びます", "Books of past months line up here", "上個月以前的書會排在這裡"),
                    color = Color(0xFFF3E2C7).copy(alpha = 0.85f), fontSize = 14.sp, fontWeight = FontWeight.Medium,
                    modifier = Modifier.align(Alignment.Center),
                )
            } else {
                Row(Modifier.fillMaxSize().padding(horizontal = 12.dp, vertical = 10.dp), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.Bottom) {
                    val spines = listOf(Color(0xFF2F6FB5), Color(0xFFC0503A), Color(0xFF3E8E5E), Color(0xFFD9A441), Color(0xFF7A5BA6))
                    months.take(8).forEachIndexed { i, (ym, count) ->
                        val base = spines[i % spines.size]
                        Box(
                            Modifier.width(34.dp).fillMaxHeight(0.75f + (count.coerceAtMost(30) / 120f))
                                .appear(delayMs = 120 + i * 50, rise = 20.dp)
                                .shadow(3.dp, RoundedCornerShape(topStart = 3.dp, topEnd = 3.dp))
                                .clip(RoundedCornerShape(topStart = 3.dp, topEnd = 3.dp))
                                .background(Brush.horizontalGradient(listOf(lerp(base, Color.Black, 0.18f), lerp(base, Color.White, 0.12f), base, lerp(base, Color.Black, 0.25f))))
                                .drawBehind {
                                    // Gilt bands near the head and the foot of the spine.
                                    val gold = Color(0xCCE9C77B)
                                    drawRect(gold, Offset(0f, 8.dp.toPx()), androidx.compose.ui.geometry.Size(size.width, 1.5.dp.toPx()))
                                    drawRect(gold, Offset(0f, size.height - 10.dp.toPx()), androidx.compose.ui.geometry.Size(size.width, 1.5.dp.toPx()))
                                },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                ym.month.getDisplayName(TextStyle.SHORT, java.util.Locale.ENGLISH).uppercase(),
                                fontWeight = FontWeight.Bold, letterSpacing = 2.sp, color = Color.White.copy(alpha = 0.92f), fontSize = 12.sp,
                                maxLines = 1, softWrap = false, modifier = Modifier.rotate(-90f).wrapContentSize(unbounded = true),
                            )
                        }
                    }
                }
            }
            Box(Modifier.align(Alignment.BottomCenter).fillMaxWidth().height(10.dp).background(Color(0xFF8A552E)))
        }
    }
}

@Composable
private fun AlbumPage(day: LocalDate, stickers: List<Sticker>, isToday: Boolean, onOpenWord: (String) -> Unit, onCamera: () -> Unit, modifier: Modifier = Modifier) {
    Box(
        modifier
            .fillMaxSize()
            .shadow(12.dp, RoundedCornerShape(topEnd = 14.dp, bottomEnd = 14.dp, topStart = 4.dp, bottomStart = 4.dp))
            .clip(RoundedCornerShape(topEnd = 14.dp, bottomEnd = 14.dp, topStart = 4.dp, bottomStart = 4.dp))
            .background(Brush.horizontalGradient(listOf(CW.paperEdge, CW.paper, CW.paper)))
            .drawBehind {
                // Faint ruled lines, like the paper of a real scrapbook.
                val step = 28.dp.toPx()
                var y = 96.dp.toPx()
                while (y < size.height - 12.dp.toPx()) {
                    drawLine(Color(0x0F2F6FB5), Offset(30.dp.toPx(), y), Offset(size.width - 18.dp.toPx(), y), 1.dp.toPx())
                    y += step
                }
            },
    ) {
        Canvas(Modifier.fillMaxHeight().width(14.dp)) {
            drawRect(Brush.horizontalGradient(listOf(Color(0xFF6B4226), Color(0xFF8C5A34))))
            drawLine(Color(0x33000000), Offset(size.width, 0f), Offset(size.width, size.height), 2f)
        }
        Column(Modifier.fillMaxSize().padding(start = 30.dp, end = 18.dp, top = 18.dp)) {
            Text(day.dayOfWeek.getDisplayName(TextStyle.FULL, L10n.locale), color = CW.primary, fontSize = 13.sp, fontWeight = FontWeight.SemiBold)
            Text(day.format(DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM).withLocale(L10n.locale)).let {
                if (L10n.current == "en") it else "${day.monthValue}月${day.dayOfMonth}日"
            }, fontSize = 30.sp, fontWeight = FontWeight.Black, color = CW.foreground)
            Spacer(Modifier.height(10.dp))
            if (stickers.isEmpty()) {
                Spacer(Modifier.weight(1f))
                Text(
                    if (isToday) tr("今日のページはまだ白紙です。", "Today's page is still blank.", "今天的頁面還是空白的。") else "",
                    fontSize = 17.sp, fontWeight = FontWeight.Medium, color = CW.muted, textAlign = TextAlign.Center, modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(18.dp))
                if (isToday) {
                    PrimaryButton(tr("今日の1枚を撮る", "Take today's photo", "拍下今天的一張"), icon = Icons.Outlined.CameraAlt, modifier = Modifier.padding(horizontal = 30.dp), onClick = onCamera)
                }
                Spacer(Modifier.weight(1f))
            } else {
                val rotations = listOf(-4f, 3f, -2f, 5f, -3f, 2f)
                stickers.take(6).chunked(2).forEachIndexed { row, pair ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), horizontalArrangement = Arrangement.SpaceEvenly) {
                        pair.forEachIndexed { col, s ->
                            val i = row * 2 + col
                            Polaroid(s, rotations[i % rotations.size], tapeLeft = i % 2 == 0, Modifier.weight(1f).padding(horizontal = 6.dp).appear(delayMs = 80 + i * 55)) { onOpenWord(s.id) }
                        }
                        if (pair.size == 1) Spacer(Modifier.weight(1f))
                    }
                }
                if (stickers.size > 6) {
                    Text("+${stickers.size - 6}", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = CW.muted, modifier = Modifier.align(Alignment.End).padding(end = 8.dp))
                }
            }
        }
    }
}

@Composable
private fun Polaroid(sticker: Sticker, rotation: Float, tapeLeft: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Box(modifier.rotate(rotation)) {
        Column(
            Modifier
                .padding(top = 6.dp)
                .shadow(6.dp, RoundedCornerShape(3.dp), ambientColor = Color(0x33000000), spotColor = Color(0x40000000))
                .background(Color.White)
                .pressable(onClick = onClick)
                .padding(start = 7.dp, end = 7.dp, top = 7.dp, bottom = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            StickerImage(sticker, Modifier.fillMaxWidth().aspectRatio(1f).background(Color(0xFFF7F4EE)), contentScale = ContentScale.Crop)
            Spacer(Modifier.height(4.dp))
            Text(sticker.word?.headword.orEmpty(), fontSize = 17.sp, fontWeight = FontWeight.Bold, color = CW.foreground, maxLines = 1)
            Text(
                ReaderLanguage.gloss(sticker.word?.meaning.orEmpty(), 14), fontSize = 11.sp, color = CW.muted,
                maxLines = 1, overflow = TextOverflow.Ellipsis,
            )
        }
        // A strip of washi tape holding the print to the page.
        Box(
            Modifier
                .align(if (tapeLeft) Alignment.TopStart else Alignment.TopEnd)
                .padding(horizontal = 10.dp)
                .rotate(if (tapeLeft) -24f else 22f)
                .size(width = 44.dp, height = 14.dp)
                .background(if (tapeLeft) Color(0xA6F2C9A0) else Color(0x99A9CFEA))
                .drawBehind {
                    val stripe = Color.White.copy(alpha = 0.35f)
                    var x = 0f
                    while (x < size.width) { drawRect(stripe, Offset(x, 0f), androidx.compose.ui.geometry.Size(3.dp.toPx(), size.height)); x += 8.dp.toPx() }
                },
        )
    }
}
