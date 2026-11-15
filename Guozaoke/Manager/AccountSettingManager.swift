//
//  AccountSettingManager.swift
//  Guozaoke
//
//  Created by scy on 2026/11/15.
//

import SwiftUI
import Combine
import SwiftSoup
import Alamofire

struct ProfileSettingModel: Codable, Equatable {
    var avatar: String = ""
    var username: String = ""
    var email: String = ""
    var nickname: String = ""
    var gender: Int = 0          // 0: 不显示, 1: 男, 2: 女
    var generation: Int = 0      // 0: 不显示, 1970: 70后, 1980: 80后, 1990: 90后, 2000: 00后, 2010: 10后
    var signature: String = ""
    var location: String = ""
    var website: String = ""
    var college: String = ""
    var company: String = ""
    var selfIntro: String = ""
    var xsrfToken: String = ""
}

struct PrivacySettingModel: Codable, Equatable {
    var online: Int = 0          // 0: 所有人, 1: 已登录用户, 2: 只有我自己
    var topics: Int = 0          // 0: 所有人, 1: 已登录用户, 2: 只有我自己
    var replies: Int = 0         // 0: 所有人, 1: 已登录用户, 2: 只有我自己
    var favorites: Int = 0       // 0: 所有人, 1: 已登录用户, 2: 只有我自己
    var dmReceive: Int = 0       // 0: 所有符合条件的用户, 1: 仅我关注的人, 2: 拒绝所有私信
    var xsrfToken: String = ""
}

struct ImageHostSettingModel: Codable, Equatable {
    var bound: Bool = false
    var mask: String = ""
    var version: String = ""
    var albumId: Int = 0
    var token: String = ""
    var autoRevoke: Bool = false
    var statusText: String = ""
    var xsrfToken: String = ""
}

@MainActor
class AccountSettingManager: ObservableObject {
    static let shared = AccountSettingManager()
    
    @Published var profile: ProfileSettingModel = ProfileSettingModel()
    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var isUploadingAvatar: Bool = false
    @Published var errorMessage: String? = nil
    
    // MARK: - 拉取 /setting 网页数据
    func fetchProfile() async {
        guard AccountState.isLogin() else { return }
        self.isLoading = true
        self.errorMessage = nil
        
        do {
            let url = "\(APIService.baseUrlString)/setting"
            let html = try await NetworkManager.shared.get(url, showErrorToast: false)
            let doc = try SwiftSoup.parse(html)
            
            var model = ProfileSettingModel()
            
            // 1. 头像提取
            if let avatarImg = try? doc.select(".form-group img.avatar").first() ?? doc.select("img.avatar").first() {
                var src = (try? avatarImg.attr("src")) ?? ""
                if !src.isEmpty {
                    if src.hasPrefix("//") {
                        src = "https:" + src
                    } else if src.hasPrefix("/") {
                        src = APIService.baseUrlString + src
                    }
                    model.avatar = src
                }
            }
            if model.avatar.isEmpty {
                model.avatar = AccountState.avatarUrl
            }
            
            // 2. 账号与基础字段
            model.username = (try? doc.select("#username").val()) ?? AccountState.userName
            model.email = (try? doc.select("#email").val()) ?? ""
            model.nickname = (try? doc.select("#nickname").val()) ?? AccountState.displayName
            
            // 3. 性别选择
            if let genderSelected = try? doc.select("#profile-gender option[selected]").val(),
               let gVal = Int(genderSelected) {
                model.gender = gVal
            } else if let firstOpt = try? doc.select("#profile-gender").val(), let gVal = Int(firstOpt) {
                model.gender = gVal
            }
            
            // 4. 出生年代选择
            if let genSelected = try? doc.select("#profile-generation option[selected]").val(),
               let genVal = Int(genSelected) {
                model.generation = genVal
            } else if let firstOpt = try? doc.select("#profile-generation").val(), let genVal = Int(firstOpt) {
                model.generation = genVal
            }
            
            // 5. 文本字段
            model.signature = (try? doc.select("#signature").val()) ?? ""
            model.location = (try? doc.select("#location").val()) ?? ""
            model.website = (try? doc.select("#website").val()) ?? ""
            model.college = (try? doc.select("#college").val()) ?? ""
            model.company = (try? doc.select("#company").val()) ?? ""
            model.selfIntro = (try? doc.select("#self_intro").text()) ?? (try? doc.select("#self_intro").val()) ?? ""
            
            // 6. 防跨站凭据 _xsrf
            let parsedXsrf = (try? doc.select("input[name=_xsrf]").val()) ?? ""
            model.xsrfToken = parsedXsrf.isEmpty ? AccountState.token() : parsedXsrf
            
            self.profile = model
            self.isLoading = false
            logger("[AccountSettingManager] 成功加载个人资料设置: \(model.username), 昵称: \(model.nickname)")
        } catch {
            self.isLoading = false
            self.errorMessage = "加载设置失败: \(error.localizedDescription)"
            logger("[AccountSettingManager] 加载设置失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 提交修改 /setting
    func saveProfile(_ model: ProfileSettingModel) async -> Bool {
        guard AccountState.isLogin() else {
            ToastView.warningToast("请先登录再保存设置")
            return false
        }
        
        self.isSaving = true
        let token = model.xsrfToken.isEmpty ? AccountState.token() : model.xsrfToken
        
        let params: [String: Any] = [
            "_xsrf": token,
            "nickname": model.nickname.trimmingCharacters(in: .whitespacesAndNewlines),
            "gender": "\(model.gender)",
            "generation": "\(model.generation)",
            "signature": model.signature.trimmingCharacters(in: .whitespacesAndNewlines),
            "location": model.location.trimmingCharacters(in: .whitespacesAndNewlines),
            "website": model.website.trimmingCharacters(in: .whitespacesAndNewlines),
            "college": model.college.trimmingCharacters(in: .whitespacesAndNewlines),
            "company": model.company.trimmingCharacters(in: .whitespacesAndNewlines),
            "self_intro": model.selfIntro.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        do {
            let url = "\(APIService.baseUrlString)/setting"
            let res = try await NetworkManager.shared.post(url, parameters: params)
            self.isSaving = false
            
            // 只要返回包含正常页面或未报错即代表保存成功
            self.profile = model
            
            // 同步更新本地 AccountState 缓存
            if var account = AccountState.getAccount() {
                if !model.nickname.isEmpty {
                    account.nickname = model.nickname
                }
                AccountState.saveAccount(account)
            }
            
            ToastView.successToast("个人信息已保存")
            hapticFeedback()
            
            // 通知主页与各视图刷新资料
            NotificationCenter.default.post(
                name: .loginSuccessNoti,
                object: nil,
                userInfo: [
                    "userName": model.username,
                    "nickname": model.nickname
                ]
            )
            return true
        } catch {
            self.isSaving = false
            ToastView.warningToast("保存失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 上传修改头像 /setting/avatar
    func uploadAvatar(image: UIImage) async -> Bool {
        guard AccountState.isLogin() else {
            ToastView.warningToast("请先登录再更换头像")
            return false
        }
        
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            ToastView.warningToast("图片解析失败，请重试")
            return false
        }
        
        self.isUploadingAvatar = true
        
        do {
            let url = "\(APIService.baseUrlString)/setting/avatar"
            _ = try await NetworkManager.shared.uploadMultipart(
                url,
                fileData: data,
                name: "avatar",
                fileName: "avatar.jpg",
                mimeType: "image/jpeg"
            )
            self.isUploadingAvatar = false
            ToastView.successToast("头像更新成功")
            hapticFeedback()
            
            // 重新拉取一次头像与设置
            await fetchProfile()
            
            // 刷新 AccountState 头像缓存
            if !self.profile.avatar.isEmpty, var acc = AccountState.getAccount() {
                acc.avatar = self.profile.avatar
                AccountState.saveAccount(acc)
            }
            
            NotificationCenter.default.post(
                name: .loginSuccessNoti,
                object: nil,
                userInfo: [
                    "userName": self.profile.username,
                    "avatar": self.profile.avatar
                ]
            )
            return true
        } catch {
            self.isUploadingAvatar = false
            ToastView.warningToast("头像上传失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 更改 ID (用户名) /setting/username
    func changeUsername(newId: String, password: String) async -> (Bool, String) {
        guard AccountState.isLogin() else {
            return (false, "请先登录")
        }
        let cleanId = newId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanId.isEmpty else {
            return (false, "新 ID 不能为空")
        }
        guard !password.isEmpty else {
            return (false, "请输入当前密码以验证身份")
        }
        
        do {
            let url = "\(APIService.baseUrlString)/setting/username"
            // 先获取页面的 _xsrf 与密码输入框 name
            let pageHtml = try await NetworkManager.shared.get(url, showErrorToast: false)
            let doc = try SwiftSoup.parse(pageHtml)
            let token = (try? doc.select("input[name=_xsrf]").val()) ?? AccountState.token()
            let currentName = (try? doc.select("#current-username").val()) ?? AccountState.userName
            
            let params: [String: Any] = [
                "_xsrf": token,
                "username": currentName,
                "new_id": cleanId,
                "password_current": password,
                "password": password
            ]
            let res = try await NetworkManager.shared.post(url, parameters: params)
            let resDoc = try SwiftSoup.parse(res)
            
            // 校验是否有错误信息返回
            if let errorAlert = try? resDoc.select(".alert-danger, .alert-error, .help-block.text-danger").first()?.text(), !errorAlert.isEmpty {
                return (false, errorAlert)
            }
            
            if let bodyText = try? resDoc.body()?.text() {
                if bodyText.contains("密码错误") || bodyText.contains("密码不正确") {
                    return (false, "密码不正确，请重新输入")
                }
            }
            
            // 成功修改后更新本地账号
            if var acc = AccountState.getAccount() {
                acc.username = cleanId
                acc.userLink = "/u/\(cleanId)"
                AccountState.saveAccount(acc)
            }
            
            self.profile.username = cleanId
            ToastView.successToast("用户名已成功修改为 \(cleanId)")
            hapticFeedback()
            
            NotificationCenter.default.post(
                name: .loginSuccessNoti,
                object: nil,
                userInfo: ["userName": cleanId]
            )
            return (true, "修改成功")
        } catch {
            return (false, "修改失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 修改密码 /setting/password
    func changePassword(oldPass: String, newPass: String, confirmPass: String) async -> (Bool, String) {
        guard AccountState.isLogin() else {
            return (false, "请先登录")
        }
        guard !oldPass.isEmpty else {
            return (false, "请输入当前密码")
        }
        guard newPass.count >= 6 else {
            return (false, "新密码长度不能少于 6 位")
        }
        guard newPass == confirmPass else {
            return (false, "两次输入的新密码不一致")
        }
        
        do {
            let url = "\(APIService.baseUrlString)/setting/password"
            let pageHtml = try await NetworkManager.shared.get(url, showErrorToast: false)
            let doc = try SwiftSoup.parse(pageHtml)
            let token = (try? doc.select("input[name=_xsrf]").val()) ?? AccountState.token()
            
            let params: [String: Any] = [
                "_xsrf": token,
                "password_old": oldPass,
                "password": newPass,
                "password_confirm": confirmPass,
                "password_again": confirmPass
            ]
            let res = try await NetworkManager.shared.post(url, parameters: params)
            let resDoc = try SwiftSoup.parse(res)
            
            if let errorAlert = try? resDoc.select(".alert-danger, .alert-error, .help-block.text-danger").first()?.text(), !errorAlert.isEmpty {
                return (false, errorAlert)
            }
            
            ToastView.successToast("密码修改成功，请牢记新密码")
            hapticFeedback()
            return (true, "密码修改成功")
        } catch {
            return (false, "密码修改失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 隐私设置 /setting/privacy
    func fetchPrivacySettings() async -> PrivacySettingModel {
        guard AccountState.isLogin() else { return PrivacySettingModel() }
        do {
            let url = "\(APIService.baseUrlString)/setting/privacy"
            let html = try await NetworkManager.shared.get(url, showErrorToast: false)
            let doc = try SwiftSoup.parse(html)
            
            var model = PrivacySettingModel()
            if let onlineVal = try? doc.select("#privacy-online option[selected]").val(), let v = Int(onlineVal) {
                model.online = v
            }
            if let topicsVal = try? doc.select("#privacy-topics option[selected]").val(), let v = Int(topicsVal) {
                model.topics = v
            }
            if let repliesVal = try? doc.select("#privacy-replies option[selected]").val(), let v = Int(repliesVal) {
                model.replies = v
            }
            if let favoritesVal = try? doc.select("#privacy-favorites option[selected]").val(), let v = Int(favoritesVal) {
                model.favorites = v
            }
            model.xsrfToken = (try? doc.select("input[name=_xsrf]").val()) ?? AccountState.token()
            
            // 获取私信接收设置
            if let dmSummaryStr = try? await NetworkManager.shared.get("\(APIService.baseUrlString)/api/dm/summary", headers: ["Accept": "application/json"], showErrorToast: false),
               let dmData = dmSummaryStr.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: dmData) as? [String: Any],
               let dataDict = json["data"] as? [String: Any],
               let policy = dataDict["policy"] as? Int {
                model.dmReceive = policy
            }
            
            return model
        } catch {
            logger("[AccountSettingManager] 获取隐私设置失败: \(error.localizedDescription)")
            return PrivacySettingModel()
        }
    }
    
    func savePrivacySettings(_ model: PrivacySettingModel) async -> Bool {
        guard AccountState.isLogin() else { return false }
        do {
            let url = "\(APIService.baseUrlString)/setting/privacy"
            let token = model.xsrfToken.isEmpty ? AccountState.token() : model.xsrfToken
            // 4个必填字段全部提交，避免 Tornado 报 400 Missing argument 错误
            let params: [String: Any] = [
                "_xsrf": token,
                "online": "\(model.online)",
                "topics": "\(model.topics)",
                "replies": "\(model.replies)",
                "favorites": "\(model.favorites)"
            ]
            _ = try await NetworkManager.shared.post(url, parameters: params)
            
            // 同步保存私信接收策略
            let dmUrl = "\(APIService.baseUrlString)/api/dm/settings"
            let dmHeaders: HTTPHeaders = [
                "X-Xsrftoken": token
            ]
            let dmParams: [String: Any] = ["policy": model.dmReceive]
            _ = try? await NetworkManager.shared.postJSON(dmUrl, parameters: dmParams, headers: dmHeaders, showErrorToast: false)
            
            ToastView.successToast("隐私设置已保存")
            hapticFeedback()
            return true
        } catch {
            ToastView.warningToast("隐私设置保存失败: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 图片托管设置 /api/media/settings
    func fetchImageHostSettings() async -> ImageHostSettingModel {
        guard AccountState.isLogin() else { return ImageHostSettingModel() }
        do {
            let url = "\(APIService.baseUrlString)/api/media/settings"
            let str = try await NetworkManager.shared.get(url, headers: ["Accept": "application/json"], showErrorToast: false)
            guard let data = str.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let d = json["data"] as? [String: Any] else {
                return ImageHostSettingModel()
            }
            
            var model = ImageHostSettingModel()
            model.bound = (d["bound"] as? Bool) ?? false
            model.mask = (d["mask"] as? String) ?? ""
            model.version = (d["version"] as? String) ?? ""
            model.albumId = (d["album_id"] as? Int) ?? 0
            model.autoRevoke = (d["revoke_on_password_change"] as? Bool) ?? false
            let err = (d["error"] as? String) ?? ""
            if model.bound {
                model.statusText = "已绑定 \(model.mask)，可以开始传图。"
            } else if err == "password_changed" {
                model.statusText = "论坛密码已更改，请重新绑定 Token。"
            } else {
                model.statusText = "尚未绑定 ImgURL Token。"
            }
            model.xsrfToken = AccountState.token()
            return model
        } catch {
            logger("[AccountSettingManager] 获取图片托管设置失败: \(error.localizedDescription)")
            return ImageHostSettingModel()
        }
    }
    
    func saveImageHostSettings(token: String, autoRevoke: Bool, version: String, albumId: Int = 0) async -> Bool {
        guard AccountState.isLogin() else { return false }
        do {
            let url = "\(APIService.baseUrlString)/api/media/settings"
            let xsrf = AccountState.token()
            let headers: HTTPHeaders = [
                "X-XSRFToken": xsrf
            ]
            let cleanToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
            let body: [String: Any] = [
                "action": "bind",
                "token": cleanToken,
                "version": version,
                "album_id": albumId,
                "revoke_on_password_change": autoRevoke
            ]
            let resStr = try await NetworkManager.shared.postJSON(url, parameters: body, headers: headers)
            guard let data = resStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ok = json["ok"] as? Bool, ok else {
                let msg = (try? JSONSerialization.jsonObject(with: resStr.data(using: .utf8) ?? Data()) as? [String: Any])?["message"] as? String ?? "保存失败"
                ToastView.warningToast(msg)
                return false
            }
            
            ToastView.successToast("图片托管设置已保存")
            hapticFeedback()
            return true
        } catch {
            ToastView.warningToast("图床配置保存失败: \(error.localizedDescription)")
            return false
        }
    }
    
    func unbindImageHost(version: String) async -> Bool {
        guard AccountState.isLogin() else { return false }
        do {
            let url = "\(APIService.baseUrlString)/api/media/settings"
            let xsrf = AccountState.token()
            let headers: HTTPHeaders = [
                "X-XSRFToken": xsrf
            ]
            let body: [String: Any] = [
                "action": "unbind",
                "version": version
            ]
            _ = try await NetworkManager.shared.postJSON(url, parameters: body, headers: headers)
            ToastView.successToast("已解绑图床托管")
            hapticFeedback()
            return true
        } catch {
            ToastView.warningToast("解绑失败: \(error.localizedDescription)")
            return false
        }
    }
}
