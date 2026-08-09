package com.mamababa.stories.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 用户信息
 */
@Serializable
data class User(
    @SerialName("id") val id: String = "",
    @SerialName("phone") val phone: String = "",
    @SerialName("nickname") val nickname: String = "爸爸妈妈",
    @SerialName("avatar") val avatar: String = "",
    @SerialName("vip_level") val vipLevel: Int = 0, // 0=普通用户, 1=月度会员, 2=年度会员
    @SerialName("vip_expire_at") val vipExpireAt: Long = 0L,
    @SerialName("created_at") val createdAt: Long = System.currentTimeMillis(),
    @SerialName("children") val children: List<Child> = emptyList()
) {
    val isVip: Boolean get() = vipLevel > 0 && vipExpireAt > System.currentTimeMillis()

    companion object {
        /** 预览/默认用户 */
        val PREVIEW = User(
            id = "preview_user",
            phone = "138****8888",
            nickname = "豆豆妈妈",
            avatar = "",
            vipLevel = 2,
            vipExpireAt = System.currentTimeMillis() + 30L * 24 * 60 * 60 * 1000,
            children = listOf(Child.PREVIEW)
        )
    }
}
