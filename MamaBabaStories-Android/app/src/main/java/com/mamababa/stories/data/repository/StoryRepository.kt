package com.mamababa.stories.data.repository

import com.mamababa.stories.MamaBabaStoriesApp
import com.mamababa.stories.data.api.ApiService
import com.mamababa.stories.data.model.*
import com.mamababa.stories.util.Constants
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import java.io.IOException

/**
 * 故事数据仓库
 * 封装故事相关的数据操作，提供 mock 数据兜底
 */
class StoryRepository(
    private val apiService: ApiService = MamaBabaStoriesApp.getInstance().apiClient.apiService
) {

    /**
     * 获取推荐故事（带 mock 兜底）
     */
    fun getRecommendStories(limit: Int = 10): Flow<Result<List<Story>>> = flow {
        try {
            val response = apiService.getRecommendStories(limit)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                emit(Result.success(response.body()!!.data ?: emptyList()))
            } else {
                emit(Result.success(Story.MOCK_LIST))
            }
        } catch (e: Exception) {
            // 网络失败时返回 mock 数据
            emit(Result.success(Story.MOCK_LIST))
        }
    }.flowOn(Dispatchers.IO)

    /**
     * 获取最近播放
     */
    fun getRecentStories(limit: Int = 10): Flow<Result<List<Story>>> = flow {
        try {
            val response = apiService.getRecentStories(limit)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                emit(Result.success(response.body()!!.data ?: emptyList()))
            } else {
                emit(Result.success(Story.MOCK_LIST.take(3)))
            }
        } catch (e: Exception) {
            emit(Result.success(Story.MOCK_LIST.take(3)))
        }
    }.flowOn(Dispatchers.IO)

    /**
     * 分页获取故事列表
     */
    fun getStories(
        category: String? = null,
        page: Int = 1,
        pageSize: Int = Constants.PAGE_SIZE,
        sort: String = "recommend"
    ): Flow<Result<PageResponse<Story>>> = flow {
        try {
            val response = apiService.getStories(category, page, pageSize, sort)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                emit(Result.success(response.body()!!.data ?: PageResponse()))
            } else {
                // Mock 分页
                val mockList = Story.MOCK_LIST
                val start = (page - 1) * pageSize
                val end = minOf(start + pageSize, mockList.size)
                val subList = if (start < mockList.size) mockList.subList(start, end) else emptyList()
                emit(Result.success(PageResponse(
                    list = subList,
                    total = mockList.size,
                    page = page,
                    pageSize = pageSize,
                    hasMore = end < mockList.size
                )))
            }
        } catch (e: Exception) {
            val mockList = Story.MOCK_LIST
            val start = (page - 1) * pageSize
            val end = minOf(start + pageSize, mockList.size)
            val subList = if (start < mockList.size) mockList.subList(start, end) else emptyList()
            emit(Result.success(PageResponse(
                list = subList,
                total = mockList.size,
                page = page,
                pageSize = pageSize,
                hasMore = end < mockList.size
            )))
        }
    }.flowOn(Dispatchers.IO)

    /**
     * 获取故事详情
     */
    suspend fun getStoryDetail(id: String): Result<Story> {
        return try {
            val response = apiService.getStoryDetail(id)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                Result.success(response.body()!!.data ?: Story.MOCK_LIST.first())
            } else {
                Result.success(Story.MOCK_LIST.first { it.id == id } ?: Story.PREVIEW_1)
            }
        } catch (e: Exception) {
            Result.success(Story.MOCK_LIST.firstOrNull { it.id == id } ?: Story.PREVIEW_1)
        }
    }

    /**
     * 搜索故事
     */
    fun searchStories(keyword: String, page: Int = 1): Flow<Result<PageResponse<Story>>> = flow {
        try {
            val response = apiService.searchStories(keyword, page)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                emit(Result.success(response.body()!!.data ?: PageResponse()))
            } else {
                val filtered = Story.MOCK_LIST.filter {
                    it.title.contains(keyword, true) || it.description.contains(keyword, true)
                }
                emit(Result.success(PageResponse(list = filtered, total = filtered.size)))
            }
        } catch (e: Exception) {
            val filtered = Story.MOCK_LIST.filter {
                it.title.contains(keyword, true) || it.description.contains(keyword, true)
            }
            emit(Result.success(PageResponse(list = filtered, total = filtered.size)))
        }
    }.flowOn(Dispatchers.IO)

    /**
     * 切换收藏
     */
    suspend fun toggleLike(storyId: String): Result<Boolean> {
        return try {
            val response = apiService.toggleLike(storyId)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                Result.success(response.body()!!.data ?: false)
            } else {
                Result.success(true)
            }
        } catch (e: Exception) {
            Result.success(true)
        }
    }

    /**
     * 上报播放
     */
    suspend fun reportPlay(storyId: String) {
        try {
            apiService.reportPlay(storyId)
        } catch (_: Exception) {}
    }
}
