package com.mamababa.stories.ui.navigation

import androidx.compose.animation.*
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material.icons.outlined.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.mamababa.stories.ui.components.MiniPlayer
import com.mamababa.stories.ui.screens.aicreate.AICreateScreen
import com.mamababa.stories.ui.screens.home.HomeScreen
import com.mamababa.stories.ui.screens.library.StoryLibraryScreen
import com.mamababa.stories.ui.screens.player.StoryPlayerScreen
import com.mamababa.stories.ui.screens.profile.ProfileScreen
import com.mamababa.stories.ui.screens.voice.RecordingScreen
import com.mamababa.stories.ui.screens.voice.VoiceCloneScreen
import com.mamababa.stories.viewmodel.*

/**
 * 导航路由常量
 */
object Routes {
    const val HOME = "home"
    const val LIBRARY = "library"
    const val AI_CREATE = "ai_create"
    const val PROFILE = "profile"

    const val PLAYER = "player"
    const val VOICE_CLONE = "voice_clone"
    const val RECORDING = "recording/{voiceId}"
    const val STORY_DETAIL = "story/{id}"

    const val ARG_STORY_ID = "id"
    const val ARG_VOICE_ID = "voiceId"

    fun storyDetail(id: String) = "story/$id"
    fun recording(voiceId: String = "") = "recording/$voiceId"
}

/**
 * 底部导航项
 */
sealed class BottomNavItem(
    val route: String,
    val title: String,
    val unselectedIcon: androidx.compose.ui.graphics.vector.ImageVector,
    val selectedIcon: androidx.compose.ui.graphics.vector.ImageVector
) {
    data object Home : BottomNavItem(Routes.HOME, "首页", Icons.Outlined.Home, Icons.Filled.Home)
    data object Library : BottomNavItem(Routes.LIBRARY, "故事库", Icons.Outlined.MenuBook, Icons.Filled.MenuBook)
    data object Create : BottomNavItem(Routes.AI_CREATE, "AI创作", Icons.Outlined.AutoAwesome, Icons.Filled.AutoAwesome)
    data object Profile : BottomNavItem(Routes.PROFILE, "我的", Icons.Outlined.Person, Icons.Filled.Person)

    companion object {
        val items = listOf(Home, Library, Create, Profile)
    }
}

/**
 * 根导航 Composable
 */
@OptIn(ExperimentalAnimationApi::class, ExperimentalMaterial3Api::class)
@Composable
fun AppNavigation(
    navController: NavHostController = rememberNavController()
) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentRoute = navBackStackEntry?.destination?.route

    // 判断是否显示底部栏（在主 tab 页面显示）
    val showBottomBar = remember(currentRoute) {
        BottomNavItem.items.any { it.route == currentRoute }
    }

    // 判断是否显示 MiniPlayer（在主 tab 页面显示，全屏播放器隐藏）
    val showMiniPlayer = remember(currentRoute) {
        currentRoute in listOf(Routes.HOME, Routes.LIBRARY, Routes.AI_CREATE, Routes.PROFILE)
    }

    // 全屏播放器路由
    val isPlayerFullScreen = currentRoute == Routes.PLAYER

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                Column {
                    if (showMiniPlayer) {
                        MiniPlayer(
                            onPlayerClick = { navController.navigate(Routes.PLAYER) }
                        )
                        HorizontalDivider(thickness = 0.5.dp, color = MaterialTheme.colorScheme.outlineVariant)
                    }
                    BottomNavigationBar(navController = navController)
                }
            }
        }
    ) { innerPadding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            NavHost(
                navController = navController,
                startDestination = Routes.HOME,
                modifier = Modifier.fillMaxSize()
            ) {
                // 主 Tab 页面
                composable(Routes.HOME) {
                    HomeScreen(
                        onStoryClick = { story ->
                            navController.navigate(Routes.PLAYER)
                        },
                        onVoiceCloneClick = { navController.navigate(Routes.VOICE_CLONE) },
                        onSeeAllStories = { navController.navigate(Routes.LIBRARY) }
                    )
                }
                composable(Routes.LIBRARY) {
                    StoryLibraryScreen(
                        onStoryClick = { navController.navigate(Routes.PLAYER) }
                    )
                }
                composable(Routes.AI_CREATE) {
                    AICreateScreen(
                        onStoryCreated = { navController.navigate(Routes.PLAYER) }
                    )
                }
                composable(Routes.PROFILE) {
                    ProfileScreen(
                        onVoiceCloneClick = { navController.navigate(Routes.VOICE_CLONE) }
                    )
                }

                // 全屏播放器
                composable(Routes.PLAYER) {
                    StoryPlayerScreen(
                        onBack = { navController.popBackStack() }
                    )
                }

                // 声音克隆
                composable(Routes.VOICE_CLONE) {
                    VoiceCloneScreen(
                        onBack = { navController.popBackStack() },
                        onStartRecording = { voiceId ->
                            navController.navigate(Routes.recording(voiceId))
                        }
                    )
                }

                // 录音页面
                composable(
                    route = Routes.RECORDING,
                    arguments = listOf(
                        navArgument(Routes.ARG_VOICE_ID) {
                            type = NavType.StringType
                            defaultValue = ""
                        }
                    )
                ) { backStackEntry ->
                    val voiceId = backStackEntry.arguments?.getString(Routes.ARG_VOICE_ID) ?: ""
                    RecordingScreen(
                        voiceId = voiceId,
                        onBack = { navController.popBackStack() },
                        onComplete = { navController.popBackStack(Routes.VOICE_CLONE, false) }
                    )
                }
            }
        }
    }
}

/**
 * 底部导航栏
 */
@Composable
private fun BottomNavigationBar(navController: NavHostController) {
    val navBackStackEntry by navController.currentBackStackEntryAsState()
    val currentDestination = navBackStackEntry?.destination

    NavigationBar(
        containerColor = MaterialTheme.colorScheme.surface,
        tonalElevation = 8.dp
    ) {
        BottomNavItem.items.forEach { item ->
            val selected = currentDestination?.hierarchy?.any { it.route == item.route } == true
            NavigationBarItem(
                selected = selected,
                onClick = {
                    if (!selected) {
                        navController.navigate(item.route) {
                            popUpTo(navController.graph.findStartDestination().id) {
                                saveState = true
                            }
                            launchSingleTop = true
                            restoreState = true
                        }
                    }
                },
                icon = {
                    Icon(
                        imageVector = if (selected) item.selectedIcon else item.unselectedIcon,
                        contentDescription = item.title
                    )
                },
                label = { Text(text = item.title, style = MaterialTheme.typography.labelSmall) },
                colors = NavigationBarItemDefaults.colors(
                    selectedIconColor = MaterialTheme.colorScheme.primary,
                    selectedTextColor = MaterialTheme.colorScheme.primary,
                    unselectedIconColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    unselectedTextColor = MaterialTheme.colorScheme.onSurfaceVariant,
                    indicatorColor = MaterialTheme.colorScheme.primaryContainer
                )
            )
        }
    }
}
