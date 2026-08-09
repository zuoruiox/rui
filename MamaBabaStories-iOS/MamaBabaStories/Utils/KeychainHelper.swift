//
//  KeychainHelper.swift
//  MamaBabaStories
//
//  Keychain 安全存储工具类
//

import Foundation
import Security

// MARK: - Keychain 错误
enum KeychainError: LocalizedError {
    case duplicateEntry
    case unknown(OSStatus)
    case itemNotFound
    case invalidData

    var errorDescription: String? {
        switch self {
        case .duplicateEntry:
            return "Keychain 条目已存在"
        case .unknown(let status):
            return "Keychain 错误（\(status)）"
        case .itemNotFound:
            return "Keychain 条目未找到"
        case .invalidData:
            return "无效的数据"
        }
    }
}

// MARK: - KeychainHelper
final class KeychainHelper {
    // MARK: - Singleton
    static let shared = KeychainHelper()

    private let serviceName: String

    // MARK: - Init
    init(serviceName: String = Bundle.main.bundleIdentifier ?? "com.mamababa.stories") {
        self.serviceName = serviceName
    }

    // MARK: - 保存数据
    func save(_ data: Data, for key: String, account: String? = nil) {
        let account = account ?? key

        // 先尝试删除旧条目
        delete(for: key, account: account)

        // 创建查询
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // 添加同步（可选）
        #if !targetEnvironment(simulator)
        query[kSecAttrSynchronizable as String] = kCFBooleanFalse
        #endif

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            Logger.error("Keychain 保存失败: \(status)", category: .general)
        }
    }

    // MARK: - 保存字符串
    func save(_ string: String, for key: String, account: String? = nil) {
        guard let data = string.data(using: .utf8) else {
            Logger.error("Keychain 字符串转 Data 失败", category: .general)
            return
        }
        save(data, for: key, account: account)
    }

    // MARK: - 获取数据
    func get(for key: String, account: String? = nil) -> Data? {
        let account = account ?? key

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status != errSecItemNotFound {
                Logger.error("Keychain 获取失败: \(status)", category: .general)
            }
            return nil
        }

        return result as? Data
    }

    // MARK: - 获取字符串
    func getString(for key: String, account: String? = nil) -> String? {
        guard let data = get(for: key, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    // MARK: - 删除数据
    @discardableResult
    func delete(for key: String, account: String? = nil) -> Bool {
        let account = account ?? key

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.error("Keychain 删除失败: \(status)", category: .general)
            return false
        }
        return true
    }

    // MARK: - 更新数据
    func update(_ data: Data, for key: String, account: String? = nil) throws {
        let account = account ?? key

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        switch status {
        case errSecSuccess:
            break
        case errSecItemNotFound:
            // 条目不存在，创建新条目
            save(data, for: key, account: account)
        default:
            throw KeychainError.unknown(status)
        }
    }

    // MARK: - 检查是否存在
    func exists(for key: String, account: String? = nil) -> Bool {
        return get(for: key, account: account) != nil
    }

    // MARK: - 清除所有
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - 便捷方法 - 认证 Token
    var authToken: String? {
        get { getString(for: KeychainKeys.authToken) }
        set {
            if let token = newValue {
                save(token, for: KeychainKeys.authToken)
            } else {
                delete(for: KeychainKeys.authToken)
            }
        }
    }

    var refreshToken: String? {
        get { getString(for: KeychainKeys.refreshToken) }
        set {
            if let token = newValue {
                save(token, for: KeychainKeys.refreshToken)
            } else {
                delete(for: KeychainKeys.refreshToken)
            }
        }
    }

    var userId: String? {
        get { getString(for: KeychainKeys.userId) }
        set {
            if let id = newValue {
                save(id, for: KeychainKeys.userId)
            } else {
                delete(for: KeychainKeys.userId)
            }
        }
    }
}

// MARK: - Codable 支持
extension KeychainHelper {
    /// 保存 Codable 对象
    func saveCodable<T: Codable>(_ object: T, for key: String, account: String? = nil) throws {
        let data = try JSONEncoder().encode(object)
        save(data, for: key, account: account)
    }

    /// 获取 Codable 对象
    func getCodable<T: Codable>(for key: String, account: String? = nil) -> T? {
        guard let data = get(for: key, account: account) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
