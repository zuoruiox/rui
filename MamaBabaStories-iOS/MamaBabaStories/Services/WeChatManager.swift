//
//  WeChatManager.swift
//  MamaBabaStories
//
//  微信登录管理 - 封装微信开放平台 SDK
//

import Foundation
import UIKit

// MARK: - 微信登录通知
extension Notification.Name {
    static let wechatLoginSuccess = Notification.Name("WeChatLoginSuccess")
    static let wechatLoginFailure = Notification.Name("WeChatLoginFailure")
    static let wechatLoginCancel = Notification.Name("WeChatLoginCancel")
}

// MARK: - 微信配置
enum WeChatConfig {
    // TODO: 替换为你的微信开放平台 AppID
    static let appID = "YOUR_WECHAT_APPID"
    static let universalLink = "https://api.mamababa-stories.com/wechat/"
}

// MARK: - WeChatManager
@MainActor
class WeChatManager: NSObject {
    static let shared = WeChatManager()

    private(set) var isWXAppInstalled = false
    private var authCompletion: ((Result<String, Error>) -> Void)?

    enum WeChatError: LocalizedError {
        case notInstalled
        case authDenied
        case authCanceled
        case authFailed(String?)
        case unknown

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "未安装微信，请先安装微信客户端"
            case .authDenied:
                return "微信授权被拒绝"
            case .authCanceled:
                return "已取消微信授权"
            case .authFailed(let msg):
                return msg ?? "微信授权失败"
            case .unknown:
                return "未知错误"
            }
        }
    }

    private override init() {
        super.init()
        // NOTE: 引入微信 SDK 后取消下面这行的注释
        // WXApi.registerApp(WeChatConfig.appID, universalLink: WeChatConfig.universalLink)
        // isWXAppInstalled = WXApi.isWXAppInstalled()
    }

    // MARK: - 注册（在 App 启动时调用）
    func registerApp() {
        // NOTE: 引入微信 SDK 后取消下面这行的注释
        // WXApi.registerApp(WeChatConfig.appID, universalLink: WeChatConfig.universalLink)
        // isWXAppInstalled = WXApi.isWXAppInstalled()
        // WXApiDelegate 设为 self
    }

    // MARK: - 发送授权请求
    func sendAuthRequest() {
        // 检查微信是否安装
        // guard WXApi.isWXAppInstalled() else {
        //     handleAuthFailure(.notInstalled)
        //     return
        // }

        // let req = SendAuthReq()
        // req.scope = "snsapi_userinfo"
        // req.state = "mamababa_stories_\(Int(Date().timeIntervalSince1970))"
        // WXApi.send(req) { [weak self] success in
        //     if !success {
        //         self?.handleAuthFailure(.authFailed(nil))
        //     }
        // }

        // ===== 开发模式临时方案 =====
        // 在微信 SDK 未集成前，使用模拟 code 进行开发测试
        // 集成 SDK 后请删除此段代码
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            let mockCode = "wx_mock_code_\(Int(Date().timeIntervalSince1970))"
            self?.handleAuthSuccess(code: mockCode)
        }
        #endif
    }

    // MARK: - 处理微信回调
    func handleOpenURL(_ url: URL) -> Bool {
        // return WXApi.handleOpen(url, delegate: self)
        return true
    }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        // return WXApi.handleOpenUniversalLink(userActivity, delegate: self)
        return true
    }

    // MARK: - 授权成功
    private func handleAuthSuccess(code: String) {
        Logger.info("微信授权成功，code: \(code)", category: .network)
        Task {
            let success = await AuthService.shared.loginWithWechat(code: code)
            if success {
                NotificationCenter.default.post(name: .wechatLoginSuccess, object: nil)
            } else {
                NotificationCenter.default.post(name: .wechatLoginFailure, object: nil)
            }
        }
    }

    // MARK: - 授权失败
    private func handleAuthFailure(_ error: WeChatError) {
        Logger.error("微信授权失败: \(error.localizedDescription)", category: .network)
        Task { @MainActor in
            AuthService.shared.errorMessage = error.localizedDescription
            AuthService.shared.showError = true
        }
        NotificationCenter.default.post(name: .wechatLoginFailure, object: nil)
    }

    // MARK: - 授权取消
    private func handleAuthCancel() {
        Logger.info("微信授权已取消", category: .network)
        NotificationCenter.default.post(name: .wechatLoginCancel, object: nil)
    }
}

// MARK: - WXApiDelegate
// NOTE: 引入微信 SDK 后取消此扩展的注释
/*
extension WeChatManager: WXApiDelegate {
    func onReq(_ req: BaseReq) {}

    func onResp(_ resp: BaseResp) {
        guard let authResp = resp as? SendAuthResp else { return }

        switch authResp.errCode {
        case 0:
            // 授权成功
            if let code = authResp.code {
                handleAuthSuccess(code: code)
            } else {
                handleAuthFailure(.authFailed("未获取到授权码"))
            }
        case -2:
            // 用户取消
            handleAuthCancel()
        case -4:
            // 用户拒绝授权
            handleAuthFailure(.authDenied)
        default:
            handleAuthFailure(.authFailed(authResp.errStr))
        }
    }
}
*/
