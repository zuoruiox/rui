package com.mamababa.stories.data.api

import com.mamababa.stories.data.model.*
import okhttp3.MultipartBody
import okhttp3.RequestBody
import retrofit2.Response
import retrofit2.http.*

/**
 * Retrofit API 服务接口
 */
interface ApiService {

    // ========== 认证 ==========
    @POST(ApiEndpoints.LOGIN)
    suspend fun login(@Body request: LoginRequest): Response<ApiResponse<LoginResponse>>

    @POST(ApiEndpoints.REFRESH_TOKEN)
    suspend fun refreshToken(@Body body: Map<String, String>): Response<ApiResponse<LoginResponse>>

    // ========== 用户 ==========
    @GET(ApiEndpoints.USER_PROFILE)
    suspend fun getUserProfile(): Response<ApiResponse<User>>

    @PUT(ApiEndpoints.UPDATE_PROFILE)
    suspend fun updateProfile(@Body user: User): Response<ApiResponse<User>>

    @GET(ApiEndpoints.CHILDREN)
    suspend fun getChildren(): Response<ApiResponse<List<Child>>>

    // ========== 故事 ==========
    @GET(ApiEndpoints.STORIES)
    suspend fun getStories(
        @Query("category") category: String? = null,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20,
        @Query("sort") sort: String = "recommend"
    ): Response<ApiResponse<PageResponse<Story>>>

    @GET(ApiEndpoints.STORY_RECOMMEND)
    suspend fun getRecommendStories(
        @Query("limit") limit: Int = 10
    ): Response<ApiResponse<List<Story>>>

    @GET(ApiEndpoints.STORY_RECENT)
    suspend fun getRecentStories(
        @Query("limit") limit: Int = 10
    ): Response<ApiResponse<List<Story>>>

    @GET(ApiEndpoints.STORY_DETAIL)
    suspend fun getStoryDetail(@Path("id") id: String): Response<ApiResponse<Story>>

    @POST(ApiEndpoints.STORY_LIKE)
    suspend fun toggleLike(@Path("id") id: String): Response<ApiResponse<Boolean>>

    @POST(ApiEndpoints.STORY_PLAY)
    suspend fun reportPlay(@Path("id") id: String): Response<ApiResponse<Unit>>

    @GET(ApiEndpoints.STORY_SEARCH)
    suspend fun searchStories(
        @Query("q") keyword: String,
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): Response<ApiResponse<PageResponse<Story>>>

    // ========== 声音模型 ==========
    @GET(ApiEndpoints.VOICE_MODELS)
    suspend fun getVoiceModels(): Response<ApiResponse<List<VoiceModel>>>

    @GET(ApiEndpoints.VOICE_MODEL_DETAIL)
    suspend fun getVoiceModel(@Path("id") id: String): Response<ApiResponse<VoiceModel>>

    @Multipart
    @POST(ApiEndpoints.VOICE_UPLOAD)
    suspend fun uploadVoiceSample(
        @Part("name") name: RequestBody,
        @Part file: MultipartBody.Part,
        @Part("duration_sec") durationSec: RequestBody
    ): Response<ApiResponse<UploadResponse>>

    @POST(ApiEndpoints.VOICE_TRAIN)
    suspend fun trainVoice(@Body request: VoiceTrainRequest): Response<ApiResponse<VoiceModel>>

    @DELETE(ApiEndpoints.VOICE_DELETE)
    suspend fun deleteVoice(@Path("id") id: String): Response<ApiResponse<Unit>>

    // ========== AI 创作 ==========
    @POST(ApiEndpoints.AI_CREATE)
    suspend fun createAIStory(@Body request: AIStoryRequest): Response<ApiResponse<AIStoryResponse>>

    @GET(ApiEndpoints.AI_STATUS)
    suspend fun getAIStoryStatus(@Path("id") id: String): Response<ApiResponse<AIStoryResponse>>

    @GET(ApiEndpoints.AI_HISTORY)
    suspend fun getAIHistory(
        @Query("page") page: Int = 1,
        @Query("page_size") pageSize: Int = 20
    ): Response<ApiResponse<PageResponse<Story>>>

    // ========== TTS ==========
    @POST(ApiEndpoints.TTS_SYNTHESIZE)
    suspend fun synthesize(@Body request: TTSRequest): Response<ApiResponse<String>>

    // ========== 会员 ==========
    @GET(ApiEndpoints.MEMBERSHIP)
    suspend fun getMembership(): Response<ApiResponse<Map<String, Any>>>

    @GET(ApiEndpoints.MEMBERSHIP_PLANS)
    suspend fun getMembershipPlans(): Response<ApiResponse<List<Map<String, Any>>>>
}
