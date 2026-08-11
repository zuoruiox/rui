//
//  APIClient.swift
//  MamaBabaStories
//
//  网络请求客户端 - 基于 async/await
//

import Foundation
import Combine

// MARK: - API Client 协议
protocol APIClientProtocol {
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T
    func requestOptional<T: Codable>(_ endpoint: APIEndpoint) async throws -> T?
    func upload<T: Codable>(_ endpoint: APIEndpoint, progressHandler: ((Double) -> Void)?) async throws -> T
    func download(_ endpoint: APIEndpoint, to destinationURL: URL, progressHandler: ((Double) -> Void)?) async throws -> URL
    func setAuthToken(_ token: String?)
}

// MARK: - API Client 实现
class APIClient: APIClientProtocol {
    // MARK: - 单例
    static let shared = APIClient()

    // MARK: - Properties
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private var authToken: String?
    private let queue = DispatchQueue(label: "com.mamababa.api", attributes: .concurrent)

    // MARK: - Init
    init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = APIConfig.timeout
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData

        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds

        self.encoder = JSONEncoder()
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder.dateEncodingStrategy = .iso8601

        // 从 Keychain 恢复 token
        self.authToken = KeychainHelper.shared.getString(for: KeychainKeys.authToken)
    }

    // MARK: - Token 管理
    func setAuthToken(_ token: String?) {
        queue.async(flags: .barrier) {
            self.authToken = token
        }
        if let token = token {
            KeychainHelper.shared.save(token, for: KeychainKeys.authToken)
        } else {
            KeychainHelper.shared.delete(for: KeychainKeys.authToken)
        }
    }

    private func getAuthToken() -> String? {
        queue.sync { authToken }
    }

    // MARK: - 通用请求
    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        let data = try await performRequest(endpoint)

        do {
            // 尝试解析为 APIResponse 包装
            let response = try decoder.decode(APIResponse<T>.self, from: data)
            if response.isSuccess, let responseData = response.data {
                return responseData
            }
            if !response.isSuccess {
                throw APIError.httpError(statusCode: response.code, message: response.message)
            }
            // 如果 data 为 nil 但 T 是 EmptyResponse
            if let empty = EmptyResponse() as? T {
                return empty
            }
            throw APIError.noData
        } catch let error as APIError {
            throw error
        } catch {
            // 尝试直接解析 T（某些接口可能不包装）
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                Logger.error("解码失败: \(error)", category: .network)
                throw APIError.decodingError(error)
            }
        }
    }

    func requestOptional<T: Codable>(_ endpoint: APIEndpoint) async throws -> T? {
        let data = try await performRequest(endpoint)

        do {
            let response = try decoder.decode(APIResponse<T>.self, from: data)
            return response.data
        } catch {
            return nil
        }
    }

    // MARK: - 文件上传
    func upload<T: Codable>(_ endpoint: APIEndpoint, progressHandler: ((Double) -> Void)? = nil) async throws -> T {
        guard let url = URL(string: endpoint.urlString) else {
            throw APIError.invalidURL
        }

        var request = createURLRequest(for: endpoint, url: url)
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let bodyData = createMultipartBody(
            boundary: boundary,
            parameters: endpoint.body ?? [:],
            fileData: endpoint.uploadData ?? Data(),
            fieldName: endpoint.uploadFieldName,
            fileName: endpoint.uploadFileName,
            mimeType: endpoint.uploadMimeType
        )

        let data = try await performUpload(request: request, data: bodyData, progressHandler: progressHandler)

        do {
            let response = try decoder.decode(APIResponse<T>.self, from: data)
            if response.isSuccess, let responseData = response.data {
                return responseData
            }
            throw APIError.uploadFailed
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.decodingError(error)
        }
    }

    // MARK: - 文件下载
    func download(_ endpoint: APIEndpoint, to destinationURL: URL, progressHandler: ((Double) -> Void)? = nil) async throws -> URL {
        guard let url = URL(string: endpoint.urlString) else {
            throw APIError.invalidURL
        }

        let request = createURLRequest(for: endpoint, url: url)

        do {
            let (location, response) = try await session.download(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: nil)
            }

            // 移动文件到目标位置
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)

            return destinationURL
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.downloadFailed
        }
    }

    // MARK: - 执行请求
    private func performRequest(_ endpoint: APIEndpoint) async throws -> Data {
        guard var urlComponents = URLComponents(string: endpoint.urlString) else {
            throw APIError.invalidURL
        }

        if let queryItems = endpoint.queryItems {
            urlComponents.queryItems = queryItems
        }

        guard let url = urlComponents.url else {
            throw APIError.invalidURL
        }

        var request = createURLRequest(for: endpoint, url: url)

        // 设置请求体
        if let body = endpoint.body, endpoint.method != "GET", !endpoint.isUpload {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                throw APIError.encodingError(error)
            }
        }

        Logger.debug("请求: \(endpoint.method) \(url.absoluteString)", category: .network)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            Logger.debug("响应: \(httpResponse.statusCode) \(url.absoluteString)", category: .network)

            // 处理状态码
            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                // Token 过期，尝试刷新
                if endpoint.requiresAuth {
                    throw APIError.tokenExpired
                }
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.notFound
            case 500...599:
                // 尝试解析错误消息
                let errorMessage = try? parseErrorMessage(from: data)
                throw APIError.serverError(message: errorMessage)
            default:
                let errorMessage = try? parseErrorMessage(from: data)
                throw APIError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw APIError.timeout
            case .cancelled:
                throw APIError.cancelled
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.networkError(error)
            default:
                throw APIError.networkError(error)
            }
        } catch {
            throw APIError.unknown(error)
        }
    }

    // MARK: - 执行上传
    private func performUpload(request: URLRequest, data: Data, progressHandler: ((Double) -> Void)?) async throws -> Data {
        // 使用进度追踪的上传
        do {
            let (responseData, response) = try await session.upload(for: request, from: data)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.uploadFailed
            }

            progressHandler?(1.0)
            return responseData
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.uploadFailed
        }
    }

    // MARK: - 创建 URLRequest
    private func createURLRequest(for endpoint: APIEndpoint, url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.timeoutInterval = endpoint.timeout

        // 通用请求头
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("zh-CN", forHTTPHeaderField: "Accept-Language")
        request.setValue(AppInfo.appVersion, forHTTPHeaderField: "X-App-Version")
        request.setValue("ios", forHTTPHeaderField: "X-Platform")

        // 认证头
        if endpoint.requiresAuth, let token = getAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - 创建 Multipart 请求体
    private func createMultipartBody(
        boundary: String,
        parameters: [String: Any],
        fileData: Data,
        fieldName: String,
        fileName: String,
        mimeType: String
    ) -> Data {
        var body = Data()
        let boundaryPrefix = "--\(boundary)\r\n"

        // 添加参数
        for (key, value) in parameters {
            body.append(boundaryPrefix.data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        // 添加文件
        body.append(boundaryPrefix.data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        // 结束标记
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        return body
    }

    // MARK: - 解析错误消息
    private func parseErrorMessage(from data: Data) throws -> String? {
        do {
            let errorResponse = try decoder.decode(APIErrorResponse.self, from: data)
            return errorResponse.message
        } catch {
            // 尝试解析为简单的 JSON
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return message
            }
            return nil
        }
    }
}

// MARK: - JSONDecoder 日期策略扩展
extension JSONDecoder.DateDecodingStrategy {
    static let iso8601WithFractionalSeconds = custom { decoder in
        let container = try decoder.singleValueContainer()
        let dateString = try container.decode(String.self)

        let formatters = [
            ISO8601DateFormatter(),
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }(),
            { () -> DateFormatter in
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd HH:mm:ss"
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }()
        ]

        for formatter in formatters {
            if let date = (formatter as? ISO8601DateFormatter)?.date(from: dateString)
                ?? (formatter as? DateFormatter)?.date(from: dateString) {
                return date
            }
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Cannot decode date: \(dateString)"
        )
    }
}

// MARK: - Mock API Client（用于测试和预览）
class MockAPIClient: APIClientProtocol {
    var mockDelay: TimeInterval = 0.5
    var shouldFail = false
    var mockError: APIError = .unknown(nil)

    func request<T: Codable>(_ endpoint: APIEndpoint) async throws -> T {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))

        if shouldFail {
            throw mockError
        }

        // 返回 mock 数据
        return try mockResponse(for: endpoint)
    }

    func requestOptional<T: Codable>(_ endpoint: APIEndpoint) async throws -> T? {
        try await Task.sleep(nanoseconds: UInt64(mockDelay * 1_000_000_000))
        if shouldFail { throw mockError }
        return nil
    }

    func upload<T: Codable>(_ endpoint: APIEndpoint, progressHandler: ((Double) -> Void)?) async throws -> T {
        // 模拟上传进度
        for progress in stride(from: 0.0, through: 1.0, by: 0.1) {
            progressHandler?(progress)
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        if shouldFail { throw mockError }
        return try mockResponse(for: endpoint)
    }

    func download(_ endpoint: APIEndpoint, to destinationURL: URL, progressHandler: ((Double) -> Void)?) async throws -> URL {
        for progress in stride(from: 0.0, through: 1.0, by: 0.2) {
            progressHandler?(progress)
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        if shouldFail { throw mockError }
        return destinationURL
    }

    func setAuthToken(_ token: String?) {}

    private func mockResponse<T: Codable>(for endpoint: APIEndpoint) throws -> T {
        let data: Data

        switch endpoint {
        case .getUserProfile:
            data = try JSONEncoder().encode(User.mock)
        case .getVoiceModels:
            data = try JSONEncoder().encode(PaginatedResponse(
                list: [VoiceModel.mockMom, VoiceModel.mockDad, VoiceModel.mockTraining],
                total: 3,
                page: 1,
                pageSize: 20,
                hasMore: false
            ))
        case .getStories, .getFeaturedStories, .getRecentStories:
            data = try JSONEncoder().encode(PaginatedResponse(
                list: Story.mockStories,
                total: Story.mockStories.count,
                page: 1,
                pageSize: 20,
                hasMore: false
            ))
        case .getFavorites:
            data = try JSONEncoder().encode(Story.mockFavorites)
        case .getChildren:
            data = try JSONEncoder().encode([Child.mock, Child.mockGirl])
        default:
            data = try JSONEncoder().encode(EmptyResponse())
        }

        return try JSONDecoder().decode(T.self, from: data)
    }
}
