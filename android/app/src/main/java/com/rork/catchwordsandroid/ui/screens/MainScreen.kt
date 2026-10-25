package com.rork.catchwordsandroid.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.ui.unit.IntOffset
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.rork.catchwordsandroid.data.AppGraph
import com.rork.catchwordsandroid.data.ConsentStatus
import com.rork.catchwordsandroid.ui.SessionViewModel
import com.rork.catchwordsandroid.ui.components.AppTab
import com.rork.catchwordsandroid.ui.components.CapsuleTabBar

/** The signed-in app: five tabs under the floating capsule bar, and the word page above them. */
@Composable
fun MainScreen(session: SessionViewModel) {
    val nav = rememberNavController()
    val entry by nav.currentBackStackEntryAsState()
    val route = entry?.destination?.route
    val tab = AppTab.entries.firstOrNull { it.route == route }
    val consent by AppGraph.consent.status.collectAsStateWithLifecycle()
    val link by com.rork.catchwordsandroid.ui.DeepLinks.route.collectAsStateWithLifecycle()
    val context = androidx.compose.ui.platform.LocalContext.current
    androidx.compose.runtime.LaunchedEffect(link) {
        val l = link ?: return@LaunchedEffect
        com.rork.catchwordsandroid.ui.DeepLinks.route.value = null
        when {
            l == "review" -> nav.selectTab(AppTab.REVIEW)
            l.startsWith("word/") -> nav.openWord(l.removePrefix("word/"))
        }
    }
    androidx.compose.runtime.LaunchedEffect(Unit) {
        com.rork.catchwordsandroid.data.Reminders.loadFromAccount()
        com.rork.catchwordsandroid.data.Reminders.refresh(context)
    }

    Box(Modifier.fillMaxSize()) {
        NavHost(
            navController = nav,
            startDestination = AppTab.HOME.route,
            // Tabs crossfade (iOS MainTabView: plain opacity); the word page rises over them like a sheet.
            enterTransition = { fadeIn(androidx.compose.animation.core.tween(220)) },
            exitTransition = { fadeOut(androidx.compose.animation.core.tween(180)) },
        ) {
            composable(AppTab.HOME.route) {
                HomeScreen(onOpenWord = { nav.openWord(it) }, onCamera = { nav.selectTab(AppTab.CAMERA) })
            }
            composable(AppTab.DEX.route) { DexScreen(onOpenWord = { nav.openWord(it) }) }
            composable(AppTab.CAMERA.route) {
                if (consent == ConsentStatus.GRANTED) {
                    CaptureScreen(onOpenWord = { nav.openWord(it) })
                } else {
                    AiConsentGateScreen(onAgree = { session.decideConsent(true) })
                }
            }
            composable(AppTab.REVIEW.route) {
                ReviewScreen(onCamera = { nav.selectTab(AppTab.CAMERA) }, onOpenWord = { nav.openWord(it) })
            }
            composable(AppTab.SETTINGS.route) { SettingsScreen(session) }
            composable(
                "word/{id}",
                arguments = listOf(navArgument("id") { type = NavType.StringType }),
                enterTransition = {
                    slideInVertically(com.rork.catchwordsandroid.ui.components.iosSpring(0.42f, 0.9f, IntOffset(1, 1))) { it / 4 } +
                        scaleIn(com.rork.catchwordsandroid.ui.components.iosSpring(0.42f, 0.9f), initialScale = 0.94f) + fadeIn(androidx.compose.animation.core.tween(180))
                },
                exitTransition = { fadeOut(androidx.compose.animation.core.tween(150)) },
                popEnterTransition = { fadeIn(androidx.compose.animation.core.tween(200)) },
                popExitTransition = {
                    slideOutVertically(androidx.compose.animation.core.tween(260, easing = androidx.compose.animation.core.FastOutLinearInEasing)) { it / 3 } +
                        scaleOut(androidx.compose.animation.core.tween(260), targetScale = 0.94f) + fadeOut(androidx.compose.animation.core.tween(220))
                },
            ) { back ->
                WordDetailScreen(stickerId = back.arguments?.getString("id").orEmpty(), onClose = {
                    pon(open = false)
                    nav.popBackStack()
                })
            }
        }

        AnimatedVisibility(
            visible = tab != null,
            enter = slideInVertically { it } + fadeIn(),
            exit = slideOutVertically { it } + fadeOut(),
            modifier = Modifier.align(Alignment.BottomCenter),
        ) {
            CapsuleTabBar(
                selected = tab,
                dark = tab == AppTab.CAMERA && consent == ConsentStatus.GRANTED,
                onSelect = { nav.selectTab(it) },
                modifier = Modifier.navigationBarsPadding().padding(bottom = 6.dp),
            )
        }
    }
}

private fun NavHostController.selectTab(tab: AppTab) {
    navigate(tab.route) {
        popUpTo(graph.findStartDestination().id) { saveState = true }
        launchSingleTop = true
        restoreState = true
    }
}

private fun NavHostController.openWord(id: String) {
    pon(open = true)
    navigate("word/$id") { launchSingleTop = true }
}

/** The bubble sound and tap of a page opening or closing (iOS SoundService.pon). */
private fun pon(open: Boolean) {
    if (AppGraph.soundsOn) AppGraph.speech.play(if (open) com.rork.catchwordsandroid.data.Speech.Sfx.PON_OPEN else com.rork.catchwordsandroid.data.Speech.Sfx.PON_BACK, 0.55f)
    com.rork.catchwordsandroid.data.Haptics.pon(open)
}
