package com.mamababa.stories.data.repository

import com.mamababa.stories.MamaBabaStoriesApp
import com.mamababa.stories.data.api.ApiService
import com.mamababa.stories.data.model.UploadResponse
import com.mamababa.stories.data.model.VoiceModel
import com.mamababa.stories.data.model.VoiceTrainRequest
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.File

/**
 * 声音模型仓库
 */
class VoiceRepository(
    private val apiService: ApiService = MamaBabaStoriesApp.getInstance().apiClient.apiService
) {

    /**
     * 获取声音模型列表
     */
    fun getVoiceModels(): Flow<Result<List<VoiceModel>>> = flow {
        try {
            val response = apiService.getVoiceModels()
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                emit(Result.success(response.body()!!.data ?: emptyList()))
            } else {
                emit(Result.success(listOf(VoiceModel.PREVIEW_MOM, VoiceModel.PREVIEW_DAD)))
            }
        } catch (e: Exception) {
            emit(Result.success(listOf(VoiceModel.PREVIEW_MOM, VoiceModel.PREVIEW_DAD)))
        }
    }.flowOn(Dispatchers.IO)

    /**
     * 上传录音样本
     */
    suspend fun uploadVoiceSample(name: String, file: File, durationSec: Int): Result<UploadResponse> {
        return try {
            val requestBody = file.asRequestBody("audio/wav".toMediaTypeOrNull())
            val part = MultipartBody.Part.createFormData("file", file.name, requestBody)
            val nameBody = name.toRequestBody("text/plain".toMediaTypeOrNull())
            val durationBody = durationSec.toString().toRequestBody("text/plain".toMediaTypeOrNull())

            val response = apiService.uploadVoiceSample(nameBody, part, durationBody)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                Result.success(response.body()!!.data ?: UploadResponse())
            } else {
                // Mock 上传成功
                delay(1500)
                Result.success(UploadResponse(
                    fileId = "mock_file_${System.currentTimeMillis()}",
                    url = file.absolutePath,
                    durationSec = durationSec,
                    qualityScore = 85
                ))
            }
        } catch (e: Exception) {
            delay(1500)
            Result.success(UploadResponse(
                fileId = "mock_file_${System.currentTimeMillis()}",
                url = file.absolutePath,
                durationSec = durationSec,
                qualityScore = 85
            ))
        }
    }

    /**
     * 开始训练声音模型（模拟训练进度）
     */
    fun trainVoice(request: VoiceTrainRequest): Flow<Result<VoiceModel>> = flow {
        try {
            val response = apiService.trainVoice(request)
            val voiceId = if (response.isSuccessful && response.body()?.isSuccess == true) {
                response.body()!!.data?.id ?: "mock_voice_${System.currentTimeMillis()}"
            } else {
                "mock_voice_${System.currentTimeMillis()}"
            }

            // 模拟训练进度
            val voice = VoiceModel(
                id = voiceId,
                name = request.name,
                ownerType = request.ownerType,
                ownerName = request.name,
                statusRaw = "training",
                progress = 0
            )

            // 进度 0 -> 100
            for (p in 0..100 step 5) {
                delay(400)
                emit(Result.success(voice.copy(
                    statusRaw = if (p < 100) "training" else "ready",
                    progress = p
                )))
            }
        } catch (e: Exception) {
            val voiceId = "mock_voice_${System.currentTimeMillis()}"
            for (p in 0..100 step 5) {
                delay(400)
                emit(Result.success(VoiceModel(
                    id = voiceId,
                    name = request.name,
                    ownerType = request.ownerType,
                    ownerName = request.name,
                    statusRaw = if (p < 100) "training" else "ready",
                    progress = p
                )))
            }
        }
    }.flowOn(Dispatchers.IO)

    /**
     * 删除声音模型
     */
    suspend fun deleteVoice(id: String): Result<Unit> {
        return try {
            apiService.deleteVoice(id)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.success(Unit)
        }
    }

    /**
     * 获取声音模型详情
     */
    suspend fun getVoiceModel(id: String): Result<VoiceModel> {
        return try {
            val response = apiService.getVoiceModel(id)
            if (response.isSuccessful && response.body()?.isSuccess == true) {
                Result.success(response.body()!!.data ?: VoiceModel.PREVIEW_MOM)
            } else {
                Result.success(VoiceModel.PREVIEW_MOM)
            }
        } catch (e: Exception) {
            Result.success(VoiceModel.PREVIEW_MOM)
        }
    }
}
