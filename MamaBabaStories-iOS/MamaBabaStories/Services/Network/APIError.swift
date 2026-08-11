//
//  APIError.swift
//  MamaBabaStories
//
//  API 错误定义
//

import Foundation

// MARK: - API 错误
enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(Error)
    case encodingError(Error)
    case networkError(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError(message: String?)
    case noData
    case uploadFailed
    case downloadFailed
    case timeout
    case cancelled
    case tokenExpired
    case unknown(Error?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL地址"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let statusCode, let message):
            return message ?? "请求失败（错误码：\(statusCode)）"
        case .decodingError:
            return "数据解析失败"
        case .encodingError:
            return "请求数据编码失败"
        case .networkError(let error):
            return "网络连接失败：\(error.localizedDescription)"
        case .unauthorized:
            return "请先登录"
        case .forbidden:
            return "没有权限访问"
        case .notFound:
            return "请求的资源不存在"
        case .serverError(let message):
            return message ?? "服务器内部错误，请稍后重试"
        case .noData:
            return "服务器未返回数据"
        case .uploadFailed:
            return "文件上传失败"
        case .downloadFailed:
            return "文件下载失败"
        case .timeout:
            return "请求超时，请检查网络连接"
        case .cancelled:
            return "请求已取消"
        case .tokenExpired:
            return "登录已过期，请重新登录"
        case .unknown(let error):
            return error?.localizedDescription ?? "发生未知错误"
        }
    }

    var isAuthError: Bool {
        switch self {
        case .unauthorized, .tokenExpired:
            return true
        default:
            return false
        }
    }

    var isNetworkError: Bool {
        switch self {
        case .networkError, .timeout:
            return true
        default:
            return false
        }
    }
}

// MARK: - API 错误响应
struct APIErrorResponse: Codable {
    let code: Int
    let message: String
    let details: [String: String]?
}

// MARK: - 通用 API 响应包装
struct APIResponse<T: Codable>: Codable {
    let code: Int
    let message: String
    let data: T?
    let timestamp: TimeInterval?

    var isSuccess: Bool {
        return code == 0 || code == 200
    }
}

// MARK: - 分页响应
struct PaginatedResponse<T: Codable>: Codable {
    let list: [T]
    let total: Int
    let page: Int
    let pageSize: Int
    let totalPages: Int

    var hasMore: Bool {
        page < totalPages
    }

    init(list: [T], total: Int, page: Int, pageSize: Int, hasMore: Bool) {
        self.list = list
        self.total = total
        self.page = page
        self.pageSize = pageSize
        self.totalPages = hasMore ? page + 1 : page
    }

    enum CodingKeys: String, CodingKey {
        case list
        case pagination
        case page, pageSize, total, totalPages
    }

    enum PaginationKeys: String, CodingKey {
        case page, pageSize, total, totalPages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        list = try container.decodeIfPresent([T].self, forKey: .list) ?? []

        if let pagination = try? container.nestedContainer(keyedBy: PaginationKeys.self, forKey: .pagination) {
            page = try pagination.decodeIfPresent(Int.self, forKey: .page) ?? 1
            pageSize = try pagination.decodeIfPresent(Int.self, forKey: .pageSize) ?? 20
            total = try pagination.decodeIfPresent(Int.self, forKey: .total) ?? 0
            totalPages = try pagination.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        } else {
            // 兼容扁平结构
            page = try container.decodeIfPresent(Int.self, forKey: .page) ?? 1
            pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize) ?? 20
            total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
            totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 1
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(list, forKey: .list)
        var pagination = container.nestedContainer(keyedBy: PaginationKeys.self, forKey: .pagination)
        try pagination.encode(page, forKey: .page)
        try pagination.encode(pageSize, forKey: .pageSize)
        try pagination.encode(total, forKey: .total)
        try pagination.encode(totalPages, forKey: .totalPages)
    }
}

// MARK: - 空响应
struct EmptyResponse: Codable {}
