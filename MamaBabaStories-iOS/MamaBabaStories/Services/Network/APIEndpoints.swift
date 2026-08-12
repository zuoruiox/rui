//
//  APIEndpoints.swift
//  MamaBabaStories
//
//  API 端点定义
//

import Foundation

// MARK: - API 端点
enum APIEndpoint {
    // MARK: - 认证
    case sendCode(phone: String)
    case login(phone: String, code: String)
    case loginWithEmail(email: String, password: String)
    case deviceLogin(deviceId: String)
    case loginWithApple(token: String)
    case refreshToken(refreshToken: String)
    case logout
    case getMe
    case updateProfile(nickname: String?, avatar: Data?)

    // MARK: - 用户
    case getUserProfile
    case updateUser(User)
    case getMembershipInfo

    // MARK: - 孩子档案
    case getChildren
    case addChild(Child)
    case updateChild(Child)
    case deleteChild(id: String)

    // MARK: - 声音模型
    case getVoiceModels
    case getVoiceModel(id: String)
    case createVoiceModel(name: String, ownerType: String)
    case deleteVoiceModel(id: String)
    case uploadRecording(voiceModelId: String, data: Data, duration: TimeInterval)
    case startTraining(voiceModelId: String)
    case getTrainingStatus(voiceModelId: String)
    case synthesizeSpeech(voiceModelId: String, text: String, config: TTSConfig?)
    case setDefaultVoice(id: String)

    // MARK: - 故事
    case getStories(page: Int, pageSize: Int, theme: String?, isFavorite: Bool?)
    case getStory(id: String)
    case createStory(AIStoryResponse)
    case updateStory(Story)
    case deleteStory(id: String)
    case toggleFavorite(id: String)
    case getFeaturedStories
    case getRecentStories(limit: Int)
    case getFavorites
    case getPlayHistory(limit: Int)

    // MARK: - AI 创作
    case generateStory(request: AIStoryRequest)
    case getGenerationStatus(requestId: String)
    case regenerateStory(storyId: String)
    case editStory(id: String, edits: String)

    // MARK: - TTS
    case synthesizeTTS(request: TTSSynthesisRequest)
    case getTTSStatus(taskId: String)
    case ttsWebSocket(storyId: String, voiceId: String)

    // MARK: - 下载
    case downloadAudio(storyId: String)
    case getDownloadURL(storyId: String)
}

// MARK: - 端点路径和方法
extension APIEndpoint {
    var path: String {
        switch self {
        // 认证
        case .sendCode:
            return "/auth/send-code"
        case .login:
            return "/auth/login"
        case .loginWithEmail:
            return "/auth/login"
        case .deviceLogin:
            return "/auth/device-login"
        case .loginWithApple:
            return "/auth/apple"
        case .refreshToken:
            return "/auth/refresh"
        case .logout:
            return "/auth/logout"
        case .getMe:
            return "/auth/me"
        case .updateProfile:
            return "/user/profile"

        // 用户
        case .getUserProfile:
            return "/user/profile"
        case .updateUser:
            return "/user/profile"
        case .getMembershipInfo:
            return "/user/membership"

        // 孩子档案
        case .getChildren:
            return "/children"
        case .addChild:
            return "/children"
        case .updateChild(let child):
            return "/children/\(child.id)"
        case .deleteChild(let id):
            return "/children/\(id)"

        // 声音模型
        case .getVoiceModels:
            return "/voices"
        case .getVoiceModel(let id):
            return "/voices/\(id)"
        case .createVoiceModel:
            return "/voices"
        case .deleteVoiceModel(let id):
            return "/voices/\(id)"
        case .uploadRecording(let voiceModelId, _, _):
            return "/voices/\(voiceModelId)/recordings"
        case .startTraining(let voiceModelId):
            return "/voices/\(voiceModelId)/train"
        case .getTrainingStatus(let voiceModelId):
            return "/voices/\(voiceModelId)/status"
        case .synthesizeSpeech(let voiceModelId, _, _):
            return "/voices/\(voiceModelId)/synthesize"
        case .setDefaultVoice(let id):
            return "/voices/\(id)/default"

        // 故事
        case .getStories:
            return "/stories"
        case .getStory(let id):
            return "/stories/\(id)"
        case .createStory:
            return "/stories"
        case .updateStory(let story):
            return "/stories/\(story.id)"
        case .deleteStory(let id):
            return "/stories/\(id)"
        case .toggleFavorite(let id):
            return "/stories/\(id)/favorite"
        case .getFeaturedStories:
            return "/stories/featured"
        case .getRecentStories:
            return "/stories/recent"
        case .getFavorites:
            return "/stories/favorites"
        case .getPlayHistory:
            return "/stories/history"

        // AI 创作
        case .generateStory:
            return "/ai/generate"
        case .getGenerationStatus(let requestId):
            return "/ai/status/\(requestId)"
        case .regenerateStory(let storyId):
            return "/ai/regenerate/\(storyId)"
        case .editStory(let id, _):
            return "/ai/edit/\(id)"

        // TTS
        case .synthesizeTTS:
            return "/tts/synthesize"
        case .getTTSStatus(let taskId):
            return "/tts/status/\(taskId)"
        case .ttsWebSocket:
            return "/tts/ws"

        // 下载
        case .downloadAudio(let storyId):
            return "/stories/\(storyId)/audio"
        case .getDownloadURL(let storyId):
            return "/stories/\(storyId)/download-url"
        }
    }

    var method: String {
        switch self {
        case .sendCode, .login, .loginWithEmail, .deviceLogin, .loginWithApple, .refreshToken,
             .addChild, .createVoiceModel, .uploadRecording, .startTraining,
             .synthesizeSpeech, .createStory, .generateStory, .regenerateStory,
             .editStory, .synthesizeTTS:
            return "POST"
        case .updateProfile, .updateUser, .updateChild, .setDefaultVoice,
             .updateStory, .toggleFavorite:
            return "PUT"
        case .deleteChild, .deleteVoiceModel, .deleteStory, .logout:
            return "DELETE"
        default:
            return "GET"
        }
    }

    var baseURL: String {
        switch self {
        case .ttsWebSocket:
            return APIConfig.wsBaseURL
        default:
            return APIConfig.baseURL
        }
    }

    var urlString: String {
        return baseURL + path
    }

    var timeout: TimeInterval {
        switch self {
        case .uploadRecording:
            return APIConfig.uploadTimeout
        case .generateStory, .synthesizeTTS, .synthesizeSpeech:
            return 60
        default:
            return APIConfig.timeout
        }
    }

    // MARK: - 查询参数
    var queryItems: [URLQueryItem]? {
        switch self {
        case .getStories(let page, let pageSize, let theme, let isFavorite):
            var items = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "pageSize", value: "\(pageSize)")
            ]
            if let theme = theme {
                items.append(URLQueryItem(name: "theme", value: theme))
            }
            if let isFavorite = isFavorite {
                items.append(URLQueryItem(name: "isFavorite", value: "\(isFavorite)"))
            }
            return items

        case .getRecentStories(let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]

        case .getPlayHistory(let limit):
            return [URLQueryItem(name: "limit", value: "\(limit)")]

        default:
            return nil
        }
    }

    // MARK: - 请求体
    var body: [String: Any]? {
        switch self {
        case .sendCode(let phone):
            return ["phone": phone]

        case .login(let phone, let code):
            return ["phone": phone, "code": code]

        case .loginWithEmail(let email, let password):
            return ["email": email, "password": password]

        case .deviceLogin(let deviceId):
            return ["deviceId": deviceId]

        case .loginWithApple(let token):
            return ["identityToken": token]

        case .refreshToken(let refreshToken):
            return ["refreshToken": refreshToken]

        case .getMe:
            return nil

        case .createVoiceModel(let name, let ownerType):
            return ["name": name, "ownerType": ownerType]

        case .uploadRecording(_, _, let duration):
            return ["duration": String(duration)]

        case .startTraining:
            return [:]

        case .synthesizeSpeech(_, let text, let config):
            var body: [String: Any] = ["text": text]
            if let config = config {
                body["speed"] = config.speed
                body["pitch"] = config.pitch
                body["emotion"] = config.emotion.rawValue
            }
            return body

        case .addChild(let child):
            return try? child.toDictionary()

        case .updateChild(let child):
            return try? child.toDictionary()

        case .updateUser(let user):
            return try? user.toDictionary()

        case .createStory(let story):
            return try? story.toDictionary()

        case .updateStory(let story):
            return try? story.toDictionary()

        case .toggleFavorite:
            return [:]

        case .setDefaultVoice:
            return [:]

        case .generateStory(let request):
            return try? request.toDictionary()

        case .regenerateStory:
            return [:]

        case .editStory(_, let edits):
            return ["edits": edits]

        case .synthesizeTTS(let request):
            return try? request.toDictionary()

        default:
            return nil
        }
    }

    // MARK: - 是否需要认证
    var requiresAuth: Bool {
        switch self {
        case .sendCode, .login, .loginWithEmail, .deviceLogin, .loginWithApple, .refreshToken,
             .getStories, .getStory, .getFeaturedStories, .getRecentStories,
             .getVoiceModels:
            return false
        default:
            return true
        }
    }

    // MARK: - 是否为上传请求
    var isUpload: Bool {
        switch self {
        case .uploadRecording, .updateProfile:
            return true
        default:
            return false
        }
    }

    // MARK: - 上传数据
    var uploadData: Data? {
        switch self {
        case .uploadRecording(_, let data, _):
            return data
        case .updateProfile(_, let avatar):
            return avatar
        default:
            return nil
        }
    }

    // MARK: - 上传字段名
    var uploadFieldName: String {
        switch self {
        case .uploadRecording:
            return "recording"
        case .updateProfile:
            return "avatar"
        default:
            return "file"
        }
    }

    // MARK: - 上传文件名
    var uploadFileName: String {
        switch self {
        case .uploadRecording:
            return "recording.wav"
        case .updateProfile:
            return "avatar.jpg"
        default:
            return "file"
        }
    }

    // MARK: - MIME 类型
    var uploadMimeType: String {
        switch self {
        case .uploadRecording:
            return "audio/wav"
        case .updateProfile:
            return "image/jpeg"
        default:
            return "application/octet-stream"
        }
    }
}

// MARK: - Codable 转 Dictionary 扩展
extension Encodable {
    func toDictionary() throws -> [String: Any]? {
        let data = try JSONEncoder().encode(self)
        let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments)
        return dict as? [String: Any]
    }
}
