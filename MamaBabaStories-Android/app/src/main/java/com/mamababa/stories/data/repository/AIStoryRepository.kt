package com.mamababa.stories.data.repository

import com.mamababa.stories.MamaBabaStoriesApp
import com.mamababa.stories.data.api.ApiService
import com.mamababa.stories.data.model.AIStoryRequest
import com.mamababa.stories.data.model.AIStoryResponse
import com.mamababa.stories.data.model.PageResponse
import com.mamababa.stories.data.model.Story
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn

/**
 * AI 故事创作仓库
 */
class AIStoryRepository(
    private val apiService: ApiService = MamaBabaStoriesApp.getInstance().apiClient.apiService
) {

    /**
     * 创建 AI 故事（模拟流式生成过程）
     */
    fun createStory(request: AIStoryRequest): Flow<Result<AIStoryResponse>> = flow {
        try {
            val response = apiService.createAIStory(request)
            val storyId = if (response.isSuccessful && response.body()?.isSuccess == true) {
                response.body()!!.data?.storyId ?: "ai_${System.currentTimeMillis()}"
            } else {
                "ai_${System.currentTimeMillis()}"
            }

            // 模拟生成过程
            val title = if (request.character.isNotEmpty()) {
                "${request.character}的${request.theme}之旅"
            } else {
                "${request.theme}的奇妙故事"
            }

            val paragraphs = listOf(
                "从前，在一个美丽的地方，",
                "住着一位可爱的小主角。",
                "有一天，他遇到了一件神奇的事情……",
                "他鼓起勇气，踏上了冒险的旅程。",
                "在路上，他结识了许多好朋友。",
                "大家一起克服了重重困难，",
                "最后，他们都收获了成长和快乐。",
                "宝贝，你也要像故事里的主角一样，",
                "勇敢、善良、快乐地长大哦！"
            )

            val sb = StringBuilder()
            for ((idx, p) in paragraphs.withIndex()) {
                delay(800)
                sb.append(p).append("\n\n")
                val progress = ((idx + 1).toFloat() / paragraphs.size * 100).toInt()
                emit(Result.success(AIStoryResponse(
                    storyId = storyId,
                    title = title,
                    textContent = sb.toString(),
                    durationSec = 300,
                    status = if (idx < paragraphs.size - 1) "generating" else "completed"
                )))
            }
        } catch (e: Exception) {
            // Mock 生成
            val storyId = "ai_${System.currentTimeMillis()}"
            val title = if (request.character.isNotEmpty()) {
                "${request.character}的${request.theme}之旅"
            } else {
                "${request.theme}的奇妙故事"
            }
            val text = """
                从前，在一个美丽的森林里，住着一只可爱的小动物。
                有一天，它踏上了一段奇妙的旅程。
                在路上，它遇到了许多好朋友，大家一起经历了有趣的冒险。
                最后，它学会了勇敢和分享，快乐地回到了家。
                宝贝，愿你也像故事里的主角一样，每天都开心快乐！
            """.trimIndent()
            delay(2000)
            emit(Result.success(AIStoryResponse(
                storyId = storyId,
                title = title,
                textContent = text,
                durationSec = 300,
                status = "completed"
            )))
        }
    }.flowOn(Dispatchers.IO)

    /**
     * 查询 AI 故事生成状态
     */
    suspend fun getStoryStatus(id: String): Result<AIStoryResponse> {
        return try {
            val response = apiService.getAIStoryStatus(id)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                Result.success(response.body()!!.data ?: AIStoryResponse())
            } else {
                Result.success(AIStoryResponse(storyId = id, status = "completed"))
            }
        } catch (e: Exception) {
            Result.success(AIStoryResponse(storyId = id, status = "completed"))
        }
    }

    /**
     * 获取 AI 创作历史
     */
    fun getHistory(page: Int = 1): Flow<Result<PageResponse<Story>>> = flow {
        try {
            val response = apiService.getAIHistory(page)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                emit(Result.success(response.body()!!.data ?: PageResponse()))
            } else {
                emit(Result.success(PageResponse(
                    list = listOf(Story.PREVIEW_AI),
                    total = 1
                )))
            }
        } catch (e: Exception) {
            emit(Result.success(PageResponse(
                list = listOf(Story.PREVIEW_AI),
                total = 1
            )))
        }
    }.flowOn(Dispatchers.IO)
}
