package com.mamababa.stories.data.api

import android.content.Context
import com.mamababa.stories.BuildConfig
import com.mamababa.stories.util.PreferenceHelper
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.util.concurrent.TimeUnit

/**
 * API 客户端，负责创建 Retrofit 和 OkHttp 实例
 * 使用简单的手动 DI（通过 Application 中初始化单例）
 */
class ApiClient private constructor(
    private val retrofit: Retrofit,
    private val okHttpClient: OkHttpClient
) {
    val apiService: ApiService by lazy { retrofit.create(ApiService::class.java) }

    /**
     * 获取用于 WebSocket 的 OkHttpClient
     */
    fun getOkHttpClient(): OkHttpClient = okHttpClient

    companion object {
        private const val BASE_URL = BuildConfig.API_BASE_URL
        private const val CONNECT_TIMEOUT = 30L
        private const val READ_TIMEOUT = 60L
        private const val WRITE_TIMEOUT = 60L

        @Volatile
        private var instance: ApiClient? = null

        fun getInstance(context: Context): ApiClient {
            return instance ?: synchronized(this) {
                instance ?: build(context.applicationContext).also { instance = it }
            }
        }

        private fun build(context: Context): ApiClient {
            // 日志拦截器
            val loggingInterceptor = HttpLoggingInterceptor().apply {
                level = if (BuildConfig.DEBUG) {
                    HttpLoggingInterceptor.Level.BODY
                } else {
                    HttpLoggingInterceptor.Level.NONE
                }
            }

            // 认证拦截器：自动附加 JWT Token
            val authInterceptor = Interceptor { chain ->
                val token = PreferenceHelper.getTokenSync(context)
                val request = chain.request().newBuilder().apply {
                    if (!token.isNullOrEmpty()) {
                        addHeader("Authorization", "Bearer $token")
                    }
                    addHeader("Accept", "application/json")
                    addHeader("Content-Type", "application/json")
                    addHeader("X-Platform", "android")
                    addHeader("X-App-Version", BuildConfig.VERSION_NAME)
                }.build()
                chain.proceed(request)
            }

            val okHttpClient = OkHttpClient.Builder()
                .connectTimeout(CONNECT_TIMEOUT, TimeUnit.SECONDS)
                .readTimeout(READ_TIMEOUT, TimeUnit.SECONDS)
                .writeTimeout(WRITE_TIMEOUT, TimeUnit.SECONDS)
                .addInterceptor(authInterceptor)
                .addInterceptor(loggingInterceptor)
                .retryOnConnectionFailure(true)
                .build()

            val retrofit = Retrofit.Builder()
                .baseUrl(BASE_URL)
                .client(okHttpClient)
                .addConverterFactory(GsonConverterFactory.create())
                .build()

            return ApiClient(retrofit, okHttpClient)
        }

        /**
         * 重置实例（用于退出登录后）
         */
        fun reset() {
            instance = null
        }
    }
}
