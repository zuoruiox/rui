package com.mamababa.stories.util

import android.content.Context
import android.content.SharedPreferences
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import com.mamababa.stories.data.model.User
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * 偏好设置工具类
 * 使用 SharedPreferences + StateFlow 实现响应式配置
 */
object PreferenceHelper {

    private lateinit var prefs: SharedPreferences
    private val gson = Gson()

    // 全局状态流
    private val _tokenFlow = MutableStateFlow<String?>(null)
    val tokenFlow: StateFlow<String?> = _tokenFlow

    private val _userFlow = MutableStateFlow<User?>(null)
    val userFlow: StateFlow<User?> = _userFlow

    private val _playbackSpeedFlow = MutableStateFlow(Constants.PLAYBACK_SPEED_DEFAULT)
    val playbackSpeedFlow: StateFlow<Float> = _playbackSpeedFlow

    /**
     * 初始化，在 Application.onCreate 中调用
     */
    fun init(context: Context) {
        prefs = context.getSharedPreferences(Constants.PREF_NAME, Context.MODE_PRIVATE)
        _tokenFlow.value = prefs.getString(Constants.KEY_TOKEN, null)
        _userFlow.value = getUser()
        _playbackSpeedFlow.value = prefs.getFloat(Constants.KEY_PLAYBACK_SPEED, Constants.PLAYBACK_SPEED_DEFAULT)
    }

    // ========== Token 管理 ==========
    fun getTokenSync(context: Context? = null): String? {
        if (!::prefs.isInitialized && context != null) {
            prefs = context.getSharedPreferences(Constants.PREF_NAME, Context.MODE_PRIVATE)
        }
        return if (::prefs.isInitialized) prefs.getString(Constants.KEY_TOKEN, null) else null
    }

    fun saveToken(token: String, refreshToken: String = "", expiresAt: Long = 0L) {
        prefs.edit()
            .putString(Constants.KEY_TOKEN, token)
            .putString(Constants.KEY_REFRESH_TOKEN, refreshToken)
            .putLong(Constants.KEY_TOKEN_EXPIRES_AT, expiresAt)
            .apply()
        _tokenFlow.value = token
    }

    fun clearToken() {
        prefs.edit()
            .remove(Constants.KEY_TOKEN)
            .remove(Constants.KEY_REFRESH_TOKEN)
            .remove(Constants.KEY_TOKEN_EXPIRES_AT)
            .apply()
        _tokenFlow.value = null
    }

    fun isLoggedIn(): Boolean = !getTokenSync().isNullOrEmpty()

    // ========== 用户信息 ==========
    fun saveUser(user: User) {
        prefs.edit().putString(Constants.KEY_USER_JSON, gson.toJson(user)).apply()
        _userFlow.value = user
    }

    fun getUser(): User? {
        val json = prefs.getString(Constants.KEY_USER_JSON, null) ?: return null
        return try {
            gson.fromJson(json, User::class.java)
        } catch (e: Exception) {
            null
        }
    }

    fun clearUser() {
        prefs.edit().remove(Constants.KEY_USER_JSON).apply()
        _userFlow.value = null
    }

    // ========== 播放设置 ==========
    fun savePlaybackSpeed(speed: Float) {
        prefs.edit().putFloat(Constants.KEY_PLAYBACK_SPEED, speed).apply()
        _playbackSpeedFlow.value = speed
    }

    fun getPlaybackSpeed(): Float =
        prefs.getFloat(Constants.KEY_PLAYBACK_SPEED, Constants.PLAYBACK_SPEED_DEFAULT)

    fun saveSleepTimer(minutes: Long) {
        prefs.edit().putLong(Constants.KEY_SLEEP_TIMER, minutes).apply()
    }

    fun getSleepTimer(): Long =
        prefs.getLong(Constants.KEY_SLEEP_TIMER, Constants.SLEEP_TIMER_OFF)

    fun setAutoPlayNext(auto: Boolean) {
        prefs.edit().putBoolean(Constants.KEY_AUTO_PLAY_NEXT, auto).apply()
    }

    fun isAutoPlayNext(): Boolean =
        prefs.getBoolean(Constants.KEY_AUTO_PLAY_NEXT, true)

    fun saveLastVoiceId(voiceId: String) {
        prefs.edit().putString(Constants.KEY_LAST_VOICE_ID, voiceId).apply()
    }

    fun getLastVoiceId(): String? =
        prefs.getString(Constants.KEY_LAST_VOICE_ID, null)

    // ========== 通用 ==========
    fun clearAll() {
        prefs.edit().clear().apply()
        _tokenFlow.value = null
        _userFlow.value = null
        _playbackSpeedFlow.value = Constants.PLAYBACK_SPEED_DEFAULT
    }
}
