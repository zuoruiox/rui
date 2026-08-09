//
//  Logger.swift
//  MamaBabaStories
//
//  日志工具类
//

import Foundation
import os.log

// MARK: - 日志分类
enum LogCategory: String {
    case network = "Network"
    case audio = "Audio"
    case voice = "Voice"
    case ai = "AI"
    case ui = "UI"
    case database = "Database"
    case general = "General"

    var category: String { rawValue }
}

// MARK: - 日志级别
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"

    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
}

// MARK: - Logger
final class Logger {
    // MARK: - Properties
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.mamababa.stories"
    private static var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()

    /// 是否启用详细日志（Debug 模式默认开启）
    private static var isVerboseLoggingEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// 日志文件 URL
    private static var logFileURL: URL? = {
        guard let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        let logsDir = cachesDir.appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        let fileName = "app_\(dateFormatter.string(from: Date()).prefix(10)).log"
        return logsDir.appendingPathComponent(fileName)
    }()

    // MARK: - 日志方法
    static func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, function: function, line: line)
    }

    static func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, function: function, line: line)
    }

    static func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, function: function, line: line)
    }

    static func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, function: function, line: line)
    }

    // MARK: - 核心日志方法
    private static func log(level: LogLevel, message: String, category: LogCategory, file: String, function: String, line: Int) {
        let timestamp = dateFormatter.string(from: Date())
        let fileName = (file as NSString).lastPathComponent
        let logMessage = "\(level.emoji) [\(level.rawValue)] [\(category.rawValue)] \(message) (\(fileName):\(line) \(function))"

        // 控制台输出
        if isVerboseLoggingEnabled || level != .debug {
            let osLog = OSLog(subsystem: subsystem, category: category.category)
            os_log("%{public}@", log: osLog, type: level.osLogType, logMessage)
        }

        // 写入日志文件
        writeToFile(logMessage: "[\(timestamp)] \(logMessage)")
    }

    // MARK: - 文件写入
    private static func writeToFile(logMessage: String) {
        guard let logURL = logFileURL else { return }

        let line = logMessage + "\n"
        guard let data = line.data(using: .utf8) else { return }

        // 使用串行队列写入文件
        logQueue.async {
            if FileManager.default.fileExists(atPath: logURL.path) {
                // 追加
                if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                // 创建新文件
                try? data.write(to: logURL)
            }

            // 限制日志文件大小（超过5MB则清理旧日志）
            if let attributes = try? FileManager.default.attributesOfItem(atPath: logURL.path),
               let fileSize = attributes[.size] as? UInt64,
               fileSize > 5 * 1024 * 1024 {
                cleanupOldLogs()
            }
        }
    }

    private static let logQueue = DispatchQueue(label: "com.mamababa.logger", qos: .utility)

    // MARK: - 日志清理
    static func cleanupOldLogs() {
        guard let logsDir = logFileURL?.deletingLastPathComponent() else { return }

        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles) else {
            return
        }

        // 保留最近7天的日志
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 24 * 3600)
        for file in files {
            if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < sevenDaysAgo {
                try? fileManager.removeItem(at: file)
            }
        }
    }

    // MARK: - 获取日志文件路径
    static func getLogFileURLs() -> [URL] {
        guard let logsDir = logFileURL?.deletingLastPathComponent() else { return [] }
        return (try? FileManager.default.contentsOfDirectory(at: logsDir, includingPropertiesForKeys: nil)) ?? []
    }
}
