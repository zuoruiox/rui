//
//  MamaBabaStoriesTests.swift
//  MamaBabaStoriesTests
//
//  单元测试 - 模型和工具类
//

import XCTest
import SwiftUI
@testable import MamaBabaStories

final class MamaBabaStoriesTests: XCTestCase {

    // MARK: - Story 模型测试
    func testStoryMockData() {
        let stories = Story.mockStories
        XCTAssertFalse(stories.isEmpty, "Mock stories should not be empty")
        XCTAssertEqual(stories.count, 6, "Should have 6 mock stories")

        let firstStory = stories[0]
        XCTAssertFalse(firstStory.title.isEmpty, "Story title should not be empty")
        XCTAssertFalse(firstStory.content.isEmpty, "Story content should not be empty")
        XCTAssertGreaterThan(firstStory.duration, 0, "Story duration should be positive")
        XCTAssertGreaterThan(firstStory.wordCount, 0, "Story word count should be positive")
    }

    func testStoryFormattedDuration() {
        let story = Story.mockStories[0]
        let formatted = story.formattedDuration
        XCTAssertFalse(formatted.isEmpty, "Formatted duration should not be empty")
        XCTAssertTrue(formatted.contains("分") || formatted.contains("秒"),
                      "Formatted duration should contain 分 or 秒")
    }

    func testStoryHasAudio() {
        let storyWithAudio = Story.mockStories[0]
        XCTAssertTrue(storyWithAudio.hasAudio, "Story with audioURL should have audio")

        let storyWithoutAudio = Story.mockStories[3]
        XCTAssertFalse(storyWithoutAudio.audioURL != nil, "Story without audio should have nil audioURL")
    }

    func testStoryFeaturedAndFavorites() {
        let featured = Story.mockFeatured
        XCTAssertEqual(featured.count, 3, "Featured stories should have 3 items")

        let favorites = Story.mockFavorites
        XCTAssertFalse(favorites.isEmpty, "Favorites should not be empty")
        for story in favorites {
            XCTAssertTrue(story.isFavorite, "All favorite stories should have isFavorite = true")
        }
    }

    // MARK: - User 模型测试
    func testUserMockData() {
        let user = User.mock
        XCTAssertFalse(user.id.isEmpty, "User ID should not be empty")
        XCTAssertFalse(user.nickname.isEmpty, "User nickname should not be empty")
        XCTAssertEqual(user.membershipTier, .premium, "Mock user should be premium")
        XCTAssertTrue(user.isPremium, "Premium user should have isPremium = true")
    }

    func testUserSettingsDefault() {
        let settings = UserSettings.default
        XCTAssertFalse(settings.kidModeEnabled, "Default kid mode should be disabled")
        XCTAssertTrue(settings.autoDownloadOnWiFi, "Default auto download should be enabled")
        XCTAssertEqual(settings.preferredPlaybackSpeed, 1.0, "Default playback speed should be 1.0")
    }

    // MARK: - Child 模型测试
    func testChildMockData() {
        let child = Child.mock
        XCTAssertFalse(child.id.isEmpty, "Child ID should not be empty")
        XCTAssertFalse(child.name.isEmpty, "Child name should not be empty")
        XCTAssertGreaterThanOrEqual(child.age, 0, "Child age should be non-negative")
        XCTAssertFalse(child.favoriteThemes.isEmpty, "Child should have favorite themes")
    }

    func testChildAgeGroup() {
        let child = Child.mock
        let ageGroup = child.ageGroup
        XCTAssertTrue(AgeGroup.allCases.contains(where: { $0 == ageGroup }),
                      "Age group should be a valid AgeGroup case")
    }

    // MARK: - VoiceModel 模型测试
    func testVoiceModelMockData() {
        let mom = VoiceModel.mockMom
        XCTAssertEqual(mom.status, .ready, "Mom voice model should be ready")
        XCTAssertEqual(mom.ownerType, .mom, "Owner type should be mom")
        XCTAssertTrue(mom.isDefault, "Mom voice should be default")
        XCTAssertGreaterThan(mom.durationSeconds, 0, "Duration should be positive")

        let training = VoiceModel.mockTraining
        XCTAssertEqual(training.status, .training, "Training model should have training status")
        XCTAssertLessThan(training.trainingProgress, 1.0, "Training progress should be less than 1")
    }

    func testVoiceModelFormattedDuration() {
        let model = VoiceModel.mockMom
        let formatted = model.formattedDuration
        XCTAssertTrue(formatted.contains("分"), "Formatted duration should contain 分")
    }

    func testVoiceOwnerType() {
        XCTAssertEqual(VoiceOwnerType.mom.emoji, "👩", "Mom emoji should be 👩")
        XCTAssertEqual(VoiceOwnerType.dad.emoji, "👨", "Dad emoji should be 👨")
        XCTAssertEqual(VoiceOwnerType.mom.defaultName, "妈妈的声音", "Mom default name should be correct")
    }

    // MARK: - StoryTheme 测试
    func testStoryThemeAllCases() {
        let themes = StoryTheme.allCases
        XCTAssertEqual(themes.count, 10, "Should have 10 story themes")
        for theme in themes {
            XCTAssertFalse(theme.icon.isEmpty, "Theme \(theme.rawValue) should have an icon")
        }
    }

    // MARK: - Date 扩展测试
    func testDateRelativeTimeString() {
        let now = Date()
        XCTAssertEqual(now.relativeTimeString, "刚刚", "Current date should be 刚刚")

        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        XCTAssertTrue(fiveMinutesAgo.relativeTimeString.contains("分钟前"),
                      "5 minutes ago should contain 分钟前")
    }

    func testDateIsToday() {
        XCTAssertTrue(Date().isToday, "Today's date should be today")
        let yesterday = Date().addingTimeInterval(-86400)
        XCTAssertTrue(yesterday.isYesterday, "Yesterday's date should be yesterday")
    }

    // MARK: - TimeInterval 扩展测试
    func testTimeIntervalFormattedAsPlaybackTime() {
        let time: TimeInterval = 65
        let formatted = time.formattedAsPlaybackTime
        XCTAssertEqual(formatted, "01:05", "65 seconds should format as 01:05")

        let hourTime: TimeInterval = 3661
        let hourFormatted = hourTime.formattedAsPlaybackTime
        XCTAssertEqual(hourFormatted, "1:01:01", "3661 seconds should format as 1:01:01")
    }

    // MARK: - Color Hex 扩展测试
    func testColorHex() {
        let color = Color(hex: "#FF5733")
        XCTAssertNotNil(color, "Color from hex should not be nil")

        let colorWithoutHash = Color(hex: "FF5733")
        XCTAssertNotNil(colorWithoutHash, "Color from hex without # should not be nil")
    }

    // MARK: - String 扩展测试
    func testStringIsValidPhoneNumber() {
        XCTAssertTrue("13812345678".isValidPhoneNumber, "Valid phone number should return true")
        XCTAssertFalse("12345".isValidPhoneNumber, "Invalid phone number should return false")
        XCTAssertFalse("abcdefghijk".isValidPhoneNumber, "Non-numeric string should return false")
    }

    func testStringTrimmed() {
        let string = "  hello world  \n"
        XCTAssertEqual(string.trimmed, "hello world", "Trimmed string should remove whitespace")
    }

    // MARK: - AppConstants 测试
    func testAppInfo() {
        XCTAssertFalse(AppInfo.appName.isEmpty, "App name should not be empty")
        XCTAssertFalse(AppInfo.bundleId.isEmpty, "Bundle ID should not be empty")
    }

    func testAudioConfig() {
        XCTAssertEqual(AudioConfig.sampleRate, 24000, "Sample rate should be 24000")
        XCTAssertEqual(AudioConfig.channels, 1, "Channels should be 1")
        XCTAssertEqual(AudioConfig.minRecordingDuration, 30, "Min recording duration should be 30 seconds")
        XCTAssertFalse(AudioConfig.playbackSpeeds.isEmpty, "Playback speeds should not be empty")
    }

    func testVoiceCloneConfig() {
        XCTAssertEqual(VoiceCloneConfig.minRecordings, 3, "Min recordings should be 3")
        XCTAssertEqual(VoiceCloneConfig.maxRecordings, 10, "Max recordings should be 10")
    }

    // MARK: - RecordingPrompt 测试
    func testRecordingPrompts() {
        let prompts = RecordingPrompt.prompts
        XCTAssertFalse(prompts.isEmpty, "Recording prompts should not be empty")
        for prompt in prompts {
            XCTAssertFalse(prompt.text.isEmpty, "Prompt text should not be empty")
            XCTAssertGreaterThan(prompt.estimatedDuration, 0, "Estimated duration should be positive")
        }
    }

    // MARK: - WordCountOption 测试
    func testWordCountOptions() {
        let options = WordCountOption.allCases
        XCTAssertEqual(options.count, 4, "Should have 4 word count options")
        for option in options {
            XCTAssertGreaterThan(option.estimatedDuration, 0, "Estimated duration should be positive")
            XCTAssertFalse(option.displayName.isEmpty, "Display name should not be empty")
        }
    }

    // MARK: - TTSemotion 测试
    func testTTSemotionAllCases() {
        let emotions = TTSemotion.allCases
        XCTAssertEqual(emotions.count, 5, "Should have 5 emotions")
        for emotion in emotions {
            XCTAssertFalse(emotion.icon.isEmpty, "Emotion \(emotion.rawValue) should have an icon")
        }
    }

    // MARK: - APIError 测试
    func testAPIErrorLocalizedDescription() {
        let errors: [APIError] = [
            .invalidURL,
            .invalidResponse,
            .httpError(statusCode: 404, message: "Not Found"),
            .timeout,
            .noData,
            .unauthorized,
            .forbidden,
            .notFound,
            .uploadFailed,
            .downloadFailed,
            .cancelled,
            .tokenExpired
        ]

        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty,
                           "Error \(error) should have a localized description")
        }
    }

    func testAPIErrorIsAuthError() {
        XCTAssertTrue(APIError.unauthorized.isAuthError, "Unauthorized should be auth error")
        XCTAssertTrue(APIError.tokenExpired.isAuthError, "Token expired should be auth error")
        XCTAssertFalse(APIError.timeout.isAuthError, "Timeout should not be auth error")
    }

    func testAPIErrorIsNetworkError() {
        XCTAssertTrue(APIError.timeout.isNetworkError, "Timeout should be network error")
        XCTAssertFalse(APIError.unauthorized.isNetworkError, "Unauthorized should not be network error")
    }

    // MARK: - EmptyResponse 测试
    func testEmptyResponseCodable() throws {
        let response = EmptyResponse()
        let data = try JSONEncoder().encode(response)
        let decoded = try JSONDecoder().decode(EmptyResponse.self, from: data)
        XCTAssertNotNil(decoded, "Decoded empty response should not be nil")
    }

    // MARK: - MembershipTier 测试
    func testMembershipTier() {
        XCTAssertEqual(MembershipTier.free.maxVoiceModels, 1, "Free tier should have 1 voice model")
        XCTAssertEqual(MembershipTier.premium.maxVoiceModels, 3, "Premium tier should have 3 voice models")
        XCTAssertEqual(MembershipTier.family.maxVoiceModels, 6, "Family tier should have 6 voice models")

        XCTAssertFalse(MembershipTier.free.canDownload, "Free tier cannot download")
        XCTAssertTrue(MembershipTier.premium.canDownload, "Premium tier can download")
        XCTAssertTrue(MembershipTier.family.canDownload, "Family tier can download")
    }

    // MARK: - PlaybackState 测试
    func testPlaybackStateEquatable() {
        XCTAssertEqual(PlaybackState.idle, PlaybackState.idle, "Same states should be equal")
        XCTAssertEqual(PlaybackState.playing, PlaybackState.playing, "Playing states should be equal")
        XCTAssertNotEqual(PlaybackState.playing, PlaybackState.paused,
                          "Different states should not be equal")
    }

    func testPlaybackStateIsPlaying() {
        XCTAssertTrue(PlaybackState.playing.isPlaying, "Playing state should have isPlaying = true")
        XCTAssertFalse(PlaybackState.paused.isPlaying, "Paused state should have isPlaying = false")
    }

    func testPlaybackStateIsActive() {
        XCTAssertTrue(PlaybackState.playing.isActive, "Playing should be active")
        XCTAssertTrue(PlaybackState.paused.isActive, "Paused should be active")
        XCTAssertFalse(PlaybackState.idle.isActive, "Idle should not be active")
        XCTAssertFalse(PlaybackState.finished.isActive, "Finished should not be active")
    }

    // MARK: - PlaybackMode 测试
    func testPlaybackModeAllCases() {
        let modes = PlaybackMode.allCases
        XCTAssertEqual(modes.count, 3, "Should have 3 playback modes")
        for mode in modes {
            XCTAssertFalse(mode.icon.isEmpty, "Playback mode \(mode.rawValue) should have an icon")
        }
    }

    // MARK: - Gender 测试
    func testGenderAllCases() {
        let genders = Gender.allCases
        XCTAssertEqual(genders.count, 3, "Should have 3 genders")
        for gender in genders {
            XCTAssertFalse(gender.emoji.isEmpty, "Gender \(gender.rawValue) should have an emoji")
        }
    }

    // MARK: - AgeGroup 测试
    func testAgeGroupAllCases() {
        let groups = AgeGroup.allCases
        XCTAssertEqual(groups.count, 4, "Should have 4 age groups")
        for group in groups {
            XCTAssertGreaterThan(group.range.lowerBound, 0,
                                 "Age group \(group.rawValue) should have positive lower bound")
        }
    }

    // MARK: - StoryStyle 测试
    func testStoryStyleAllCases() {
        let styles = StoryStyle.allCases
        XCTAssertEqual(styles.count, 6, "Should have 6 story styles")
    }

    // MARK: - QualityLevel 测试
    func testQualityLevelColor() {
        let levels: [QualityLevel] = [.excellent, .good, .acceptable, .poor]
        for level in levels {
            XCTAssertFalse(level.color.isEmpty, "Quality level \(level.rawValue) should have a color")
        }
    }

    // MARK: - RecordingQuality 测试
    func testRecordingQualityIsPassing() {
        let goodQuality = RecordingQuality(
            snr: 35,
            peakLevel: 0.7,
            hasClipping: false,
            isTooQuiet: false,
            isTooLoud: false,
            overallScore: 85
        )
        XCTAssertTrue(goodQuality.isPassing, "Good quality should pass")

        let poorQuality = RecordingQuality(
            snr: 10,
            peakLevel: 0.99,
            hasClipping: true,
            isTooQuiet: false,
            isTooLoud: true,
            overallScore: 40
        )
        XCTAssertFalse(poorQuality.isPassing, "Poor quality should not pass")
    }
}
