package com.rork.catchwordsandroid.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.unit.IntOffset
import com.rork.catchwordsandroid.ui.components.appear
import com.rork.catchwordsandroid.ui.components.iosSpring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowForward
import androidx.compose.material.icons.automirrored.outlined.VolumeUp
import androidx.compose.material.icons.outlined.CameraAlt
import androidx.compose.material.icons.outlined.Replay
import androidx.compose.material.icons.outlined.Verified
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.rork.catchwordsandroid.data.AppGraph
import com.rork.catchwordsandroid.data.ReaderLanguage
import com.rork.catchwordsandroid.data.tr
import com.rork.catchwordsandroid.ui.QuizChoice
import com.rork.catchwordsandroid.ui.ReviewCard
import com.rork.catchwordsandroid.ui.ReviewUiState
import com.rork.catchwordsandroid.ui.ReviewViewModel
import com.rork.catchwordsandroid.ui.components.AppBackground
import com.rork.catchwordsandroid.ui.components.PrimaryButton
import com.rork.catchwordsandroid.ui.components.SecondaryButton
import com.rork.catchwordsandroid.ui.components.SectionCard
import com.rork.catchwordsandroid.ui.components.StickerImage
import com.rork.catchwordsandroid.ui.components.pressable
import com.rork.catchwordsandroid.ui.components.readingOf
import com.rork.catchwordsandroid.ui.theme.CW

/** きょうの復習: header, progress and memory bar, then one 4-choice card at a time. */
@Composable
fun ReviewScreen(onCamera: () -> Unit, onOpenWord: (String) -> Unit, vm: ReviewViewModel = viewModel()) {
    val ui by vm.ui.collectAsStateWithLifecycle()
    val dex by AppGraph.dex.state.collectAsStateWithLifecycle()
    val total = ui.queue.size.coerceAtLeast(1)
    val progress by animateFloatAsState(if (ui.queue.isEmpty()) 0.08f else (ui.index + if (ui.picked != null) 1 else 0).toFloat() / total, iosSpring(0.6f, 0.8f), label = "progress")

    AppBackground {
        Column(Modifier.fillMaxSize().statusBarsPadding()) {
            Column(Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
                Text(tr("きょうの復習", "Today's review", "今日複習"), fontSize = 30.sp, fontWeight = FontWeight.Black, color = CW.foreground)
                Text(
                    when {
                        ui.streak > 0 -> tr("${ui.streak}日連続・今日 ${ui.doneToday} 問", "${ui.streak}-day streak · ${ui.doneToday} today", "連續 ${ui.streak} 天・今天 ${ui.doneToday} 題")
                        else -> tr("今日から復習を始めましょう", "Start reviewing today", "從今天開始複習吧")
                    },
                    fontSize = 14.sp, color = CW.muted,
                )
                Spacer(Modifier.height(8.dp))
                Box(Modifier.fillMaxWidth().height(6.dp).clip(CircleShape).background(CW.surface2)) {
                    Box(Modifier.fillMaxWidth(progress.coerceIn(0f, 1f)).fillMaxHeight().clip(CircleShape).background(CW.brandGradient))
                }
                Spacer(Modifier.height(8.dp))
                MemoryBar(dex.memoryLevelCounts)
            }
            Box(Modifier.weight(1f)) {
                val card = ui.current
                when {
                    !ui.hasLoaded -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator(color = CW.primary) }
                    ui.error != null && ui.queue.isEmpty() -> EmptyReview(ui.error.orEmpty(), tr("もう一度読み込む", "Try again", "重新載入"), Icons.Outlined.Replay) { vm.load() }
                    ui.queue.isEmpty() -> EmptyReview(
                        if (ui.capped) tr("今日の上限まで復習しました。おつかれさま！", "You reached today's limit. Nice work!", "今天的複習已達上限，辛苦了！")
                        else tr("今日復習する単語はありません。\n新しい単語をキャッチすると、10分後に最初の復習が出ます。", "No words to review today.\nCatch a new word and its first review comes 10 minutes later.", "今天沒有要複習的單字。\n收集新單字後，10 分鐘後就會出現第一次複習。"),
                        tr("単語を撮りに行く", "Go catch words", "去拍單字"), Icons.Outlined.CameraAlt, onCamera,
                    )
                    card == null -> Finished(ui, onRetry = vm::retryMissed, onMore = vm::loadMore)
                    else -> androidx.compose.animation.AnimatedContent(
                        targetState = card.sticker.id to ui.index,
                        transitionSpec = {
                            (slideInHorizontally(iosSpring(0.45f, 0.86f, IntOffset(1, 1))) { it / 3 } + fadeIn(tween(200))) togetherWith
                                (slideOutHorizontally(tween(220)) { -it / 4 } + fadeOut(tween(160)))
                        },
                        label = "question",
                    ) { _ -> QuizCard(card, ui, vm::answer) }
                }
                androidx.compose.animation.AnimatedVisibility(
                    visible = ui.picked != null && card != null && !ui.grading,
                    enter = slideInVertically(iosSpring(0.42f, 0.84f, IntOffset(1, 1))) { it } + fadeIn(tween(160)),
                    exit = slideOutVertically(tween(200)) { it } + fadeOut(tween(180)),
                    modifier = Modifier.align(Alignment.BottomCenter),
                ) {
                    if (card != null) AnswerPanel(card, ui.isCorrect == true, onOpen = { onOpenWord(card.sticker.id) }, onNext = vm::next)
                }
            }
        }
    }
}

@Composable
private fun MemoryBar(counts: List<Int>) {
    val total = counts.sum()
    val grow = remember { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(total > 0) { if (total > 0) grow.animateTo(1f, tween(700, easing = androidx.compose.animation.core.FastOutSlowInEasing)) }
    Box(Modifier.fillMaxWidth().height(10.dp).clip(CircleShape).background(CW.surface2)) {
        if (total > 0) {
            Row(Modifier.fillMaxWidth(grow.value).fillMaxHeight().clip(CircleShape)) {
                counts.forEachIndexed { i, n ->
                    if (n > 0) Box(Modifier.weight(n.toFloat()).fillMaxHeight().background(CW.memoryLevels[i]))
                }
            }
        }
    }
    if (total > 0) {
        Row(Modifier.fillMaxWidth().padding(top = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(tr("忘れかけ", "Fading", "快忘了"), fontSize = 11.sp, color = CW.memoryLevels[0])
            Text(tr("記憶の状態 ${total}語", "Memory · $total words", "記憶狀態 $total 個"), fontSize = 11.sp, color = CW.muted)
            Text(tr("しっかり", "Solid", "很牢固"), fontSize = 11.sp, color = CW.memoryLevels[5])
        }
    }
}

@Composable
private fun QuizCard(card: ReviewCard, ui: ReviewUiState, onAnswer: (QuizChoice) -> Unit) {
    val w = card.sticker.word
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(start = 16.dp, end = 16.dp, top = 6.dp, bottom = 300.dp)) {
        SectionCard(padding = 14.dp) {
            Box(Modifier.fillMaxWidth().height(220.dp).clip(RoundedCornerShape(20.dp)).background(Color(0xFFEAF0F7))) {
                StickerImage(card.sticker, Modifier.fillMaxSize().padding(if (card.sticker.isCutout) 14.dp else 0.dp), contentScale = if (card.sticker.isCutout) ContentScale.Fit else ContentScale.Crop, emojiSize = 80)
                Text(
                    "${ui.index + 1} / ${ui.queue.size}", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = Color.White,
                    modifier = Modifier.align(Alignment.TopStart).padding(10.dp).clip(CircleShape).background(Color(0x99000000)).padding(horizontal = 10.dp, vertical = 4.dp),
                )
            }
            Spacer(Modifier.height(14.dp))
            Text(
                tr("「${ReaderLanguage.gloss(w?.meaning.orEmpty())}」はどれ？", "Which one is “${ReaderLanguage.gloss(w?.meaning.orEmpty())}”?", "「${ReaderLanguage.gloss(w?.meaning.orEmpty())}」是哪一個？"),
                fontSize = 19.sp, fontWeight = FontWeight.Bold, color = CW.foreground,
            )
            ui.gradeError?.let { Text(it, color = CW.destructive, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp)) }
            Spacer(Modifier.height(12.dp))
            ui.choices.chunked(2).forEachIndexed { r, row ->
                Row(Modifier.fillMaxWidth().padding(vertical = 5.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    row.forEachIndexed { k, c ->
                        ChoiceButton(c, ui, w?.headword.orEmpty(), Modifier.weight(1f).appear(delayMs = 90 + (r * 2 + k) * 45)) { onAnswer(c) }
                    }
                }
            }
        }
    }
}

@Composable
private fun ChoiceButton(choice: QuizChoice, ui: ReviewUiState, answer: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val picked = ui.picked
    val isAnswer = choice.headword == answer
    val isWrongPick = picked != null && picked == choice.headword && !isAnswer
    val revealed = picked != null && (isAnswer || isWrongPick)
    val bg by animateColorAsState(
        when {
            picked == null -> CW.card
            isAnswer -> CW.ok.copy(alpha = 0.14f)
            isWrongPick -> CW.destructive.copy(alpha = 0.12f)
            else -> CW.card
        },
        tween(220), label = "bg",
    )
    val border by animateColorAsState(
        when {
            picked == null -> CW.border
            isAnswer -> CW.ok
            isWrongPick -> CW.destructive
            else -> CW.border
        },
        tween(220), label = "border",
    )
    // Choices that are neither the answer nor the pick step back once the answer is known.
    val dim by animateFloatAsState(if (picked != null && !revealed) 0.45f else 1f, tween(260), label = "dim")
    val shake = remember { androidx.compose.animation.core.Animatable(0f) }
    val pop = remember { androidx.compose.animation.core.Animatable(1f) }
    LaunchedEffect(isWrongPick, picked != null && isAnswer) {
        if (isWrongPick) {
            for (x in listOf(-10f, 9f, -7f, 5f, -3f, 0f)) shake.animateTo(x, tween(45))
        } else if (picked != null && isAnswer) {
            pop.animateTo(1.06f, tween(110))
            pop.animateTo(1f, iosSpring(0.35f, 0.5f))
        }
    }
    Box(
        modifier
            .graphicsLayer { translationX = shake.value * density; scaleX = pop.value; scaleY = pop.value; alpha = dim }
            .heightIn(min = 76.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(bg)
            .border(if (revealed) 2.dp else 1.dp, border, RoundedCornerShape(18.dp))
            .pressable(enabled = picked == null && !ui.grading, onClick = onClick)
            .padding(10.dp),
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(readingOf(choice.reading, null), fontSize = 11.sp, color = CW.primaryInk, maxLines = 1)
            Text(choice.headword, fontSize = 24.sp, fontWeight = FontWeight.Bold, color = CW.foreground, maxLines = 1)
        }
        androidx.compose.animation.AnimatedVisibility(
            visible = revealed,
            enter = scaleIn(iosSpring(0.32f, 0.55f), initialScale = 0.3f) + fadeIn(tween(120)),
            modifier = Modifier.align(Alignment.TopEnd),
        ) {
            Icon(
                if (isAnswer) Icons.Filled.CheckCircle else Icons.Filled.Cancel, null,
                tint = if (isAnswer) CW.ok else CW.destructive,
                modifier = Modifier.size(22.dp).clip(CircleShape).background(Color.White),
            )
        }
    }
}

@Composable
private fun AnswerPanel(card: ReviewCard, correct: Boolean, onOpen: () -> Unit, onNext: () -> Unit) {
    val w = card.sticker.word
    Column(
        Modifier
            .fillMaxWidth()
            .shadow(24.dp, RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp))
            .clip(RoundedCornerShape(topStart = 30.dp, topEnd = 30.dp))
            .background(CW.card)
            .padding(start = 20.dp, end = 20.dp, top = 18.dp, bottom = 96.dp),
    ) {
        Box(Modifier.align(Alignment.CenterHorizontally).padding(bottom = 10.dp).size(width = 40.dp, height = 5.dp).clip(CircleShape).background(CW.border))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.appear(rise = 6.dp)) {
            Icon(if (correct) Icons.Filled.CheckCircle else Icons.Filled.Cancel, null, tint = if (correct) CW.ok else CW.destructive, modifier = Modifier.size(24.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                if (correct) tr("正解！", "Correct!", "答對了！") else tr("おしい！", "Not quite!", "差一點！"),
                fontSize = 22.sp, fontWeight = FontWeight.Black, color = if (correct) CW.ok else CW.destructive,
            )
        }
        Spacer(Modifier.height(6.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(readingOf(w?.readingZhuyin, w?.pinyin), fontSize = 14.sp, color = CW.primaryInk)
                Text(w?.headword.orEmpty(), fontSize = 34.sp, fontWeight = FontWeight.Black, color = CW.foreground)
                Text(w?.meaning.orEmpty(), fontSize = 15.sp, color = CW.muted)
            }
            Icon(
                Icons.AutoMirrored.Outlined.VolumeUp, tr("発音を聞く", "Listen", "聆聽發音"), tint = CW.primary,
                modifier = Modifier.size(48.dp).clip(CircleShape).background(CW.accent).pressable { AppGraph.speech.speak(w?.headword.orEmpty(), AppGraph.profile.target) }.padding(11.dp),
            )
        }
        w?.exampleSentence?.let { ex ->
            Spacer(Modifier.height(8.dp))
            Text(ex, fontSize = 15.sp, color = CW.foreground)
        }
        Spacer(Modifier.height(14.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            SecondaryButton(tr("単語のページ", "Word page", "單字頁面"), onClick = onOpen)
            PrimaryButton(tr("次へ", "Next", "下一題"), icon = Icons.AutoMirrored.Outlined.ArrowForward, modifier = Modifier.weight(1f), onClick = onNext)
        }
    }
}

@Composable
private fun Finished(ui: ReviewUiState, onRetry: () -> Unit, onMore: () -> Unit) {
    val total = ui.queue.size.coerceAtLeast(1)
    val rate = ui.correctCount.toFloat() / total
    val ring = remember { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(Unit) {
        com.rork.catchwordsandroid.data.Haptics.success()
        if (AppGraph.soundsOn) AppGraph.speech.play(com.rork.catchwordsandroid.data.Speech.Sfx.POP, 0.7f)
        ring.animateTo(rate, tween(1100, easing = androidx.compose.animation.core.FastOutSlowInEasing))
    }
    val shown = (ring.value * total).let { kotlin.math.round(it).toInt() }.coerceAtMost(ui.correctCount)
    Box(Modifier.fillMaxSize()) {
        Column(Modifier.fillMaxSize().padding(16.dp)) {
            SectionCard(padding = 24.dp, modifier = Modifier.appear()) {
                Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(Modifier.size(132.dp), contentAlignment = Alignment.Center) {
                        val track = CW.surface2
                        val okc = CW.ok
                        val pc = CW.primary
                        androidx.compose.foundation.Canvas(Modifier.fillMaxSize()) {
                            val st = androidx.compose.ui.graphics.drawscope.Stroke(width = 12.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
                            drawArc(track, 0f, 360f, false, style = st, topLeft = androidx.compose.ui.geometry.Offset(6.dp.toPx(), 6.dp.toPx()), size = androidx.compose.ui.geometry.Size(size.width - 12.dp.toPx(), size.height - 12.dp.toPx()))
                            drawArc(
                                androidx.compose.ui.graphics.Brush.sweepGradient(listOf(pc, okc, pc)), -90f, 360f * ring.value, false, style = st,
                                topLeft = androidx.compose.ui.geometry.Offset(6.dp.toPx(), 6.dp.toPx()), size = androidx.compose.ui.geometry.Size(size.width - 12.dp.toPx(), size.height - 12.dp.toPx()),
                            )
                        }
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text("$shown", fontSize = 40.sp, fontWeight = FontWeight.Black, color = CW.foreground, style = androidx.compose.ui.text.TextStyle(fontFeatureSettings = "tnum"))
                            Text("/ ${ui.queue.size}", fontSize = 13.sp, fontWeight = FontWeight.SemiBold, color = CW.muted)
                        }
                    }
                    Spacer(Modifier.height(14.dp))
                    Text(tr("今日の復習が終わりました", "Today's review is done", "今天的複習完成了"), fontSize = 20.sp, fontWeight = FontWeight.Bold, color = CW.foreground)
                    Text(tr("${ui.queue.size}問中 ${ui.correctCount}問 正解", "${ui.correctCount} of ${ui.queue.size} correct", "${ui.queue.size} 題中答對 ${ui.correctCount} 題"), fontSize = 15.sp, color = CW.muted)
                    Spacer(Modifier.height(18.dp))
                    if (ui.missed.isNotEmpty()) {
                        PrimaryButton(tr("間違えた${ui.missed.size}語をもう一度", "Retry ${ui.missed.size} missed", "再練習答錯的 ${ui.missed.size} 個"), icon = Icons.Outlined.Replay, onClick = onRetry)
                        Spacer(Modifier.height(8.dp))
                    }
                    if (ui.moreAvailable) SecondaryButton(tr("もっと復習する", "Review more", "繼續複習"), onClick = onMore)
                }
            }
        }
        if (rate >= 0.8f) Confetti(active = true, modifier = Modifier.fillMaxSize())
    }
}

@Composable
private fun EmptyReview(text: String, action: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onAction: () -> Unit) {
    Column(Modifier.fillMaxSize().padding(16.dp)) {
        SectionCard(padding = 24.dp) {
            Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(Icons.Outlined.Verified, null, tint = CW.primary, modifier = Modifier.size(60.dp))
                Spacer(Modifier.height(12.dp))
                Text(text, fontSize = 16.sp, color = CW.foreground, textAlign = TextAlign.Center, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(18.dp))
                PrimaryButton(action, icon = icon, onClick = onAction)
            }
        }
    }
}
