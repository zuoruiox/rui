package com.mamababa.stories.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * 孩子信息
 */
@Serializable
data class Child(
    @SerialName("id") val id: String = "",
    @SerialName("name") val name: String = "宝贝",
    @SerialName("gender") val gender: Int = 0, // 0=未知, 1=男孩, 2=女孩
    @SerialName("age") val age: Int = 3,
    @SerialName("birthday") val birthday: String = "",
    @SerialName("avatar") val avatar: String = ""
) {
    val ageRange: String
        get() = when {
            age <= 2 -> "0-2岁"
            age <= 4 -> "3-4岁"
            age <= 6 -> "5-6岁"
            age <= 9 -> "7-9岁"
            else -> "10岁+"
        }

    companion object {
        val PREVIEW = Child(
            id = "child_1",
            name = "豆豆",
            gender = 1,
            age = 4,
            birthday = "2021-06-01"
        )
    }
}
