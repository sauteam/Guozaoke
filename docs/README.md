# Guozaoke iOS 更新记录与版本回溯

本文档用于记录 Guozaoke（过早客）iOS 客户端各版本的迭代历史、核心架构变更、重要 Bug 修复以及代码回溯指引。

---

## 目录

- [当前迭代与重点修复 (2026-11)](#当前迭代与重点修复-2026-11)
  - [1. 数据获取与网络反爬 (WAF) 突破](#1-数据获取与网络反爬-waf-突破)
  - [2. 用户在线状态与等级微标](#2-用户在线状态与等级微标)
  - [3. 个人主页与详情页 404 修复](#3-个人主页与详情页-404-修复)
  - [4. iPhone Duo 双屏与折叠屏适配](#4-iphone-duo-双屏与折叠屏适配)
  - [5. 桌面小组件 (Widget) 交互强化](#5-桌面小组件-widget-交互强化)
  - [6. 关注功能修复与全场景列表头像用户ID解析强化](#6-关注功能修复与全场景列表头像用户id解析强化)
  - [7. 点赞 403 修复与信用等级展示去重](#7-点赞-403-修复与信用等级展示去重)
- [历史发布版本记录](#历史发布版本记录)
- [核心架构与代码回溯指引](#核心架构与代码回溯指引)

---

## 当前迭代与重点修复 (2026-11)

### 1. 数据获取与网络反爬 (WAF) 突破
* **背景与问题**：
  * 网站服务端升级了阿里云盾/高防 WAF 机制，App 请求时返回 403 页面并附带 JavaScript 计算脚本（生成 `acw_sc__v2` Cookie），导致无法登录和获取列表数据。
* **修改与优化**：
  * **WAF Cookie 动态解密注入**：在网络层逆向实现了 WAF 动态 Token（`acw_sc__v2`）生成算法，在遭遇 403/JavaScript 质询时自动运算并存入 `HTTPCookieStorage`。
  * **网络请求与重试机制**：完善 `NetworkManager.swift`，统一 iOS Safari User-Agent，增加针对 403 的自动重试流程与 Cookie 持久化。
  * **主要涉及文件**：
    * `Guozaoke/APIService/NetworkManager.swift`
    * `Guozaoke/View/Login/LoginService.swift`
    * `Guozaoke/APIService/APIService.swift`

### 2. 用户在线状态与等级微标
* **背景与需求**：
  * 过早客网页版新增了用户在线标记（`.gzk-online`）与用户信用等级（`.gzk-credit-level`，如 `Lv.3`），App 需要直观展示。
* **修改与优化**：
  * **在线小绿点**：在帖子列表/详情页楼主头像、评论回复者头像以及个人主页大头像右下角增加精致的绿原点标记（仅在线时显示，离线时不占位展示）。
  * **等级徽章**：在用户名旁边添加紧凑型等级微标（如 `Lv.3`）。
  * **个人资料扩展**：在个人主页“资料”选项卡中详细列出“等级（含信用积分详细说明）”、“状态: 在线 🟢”，并补充年代（80后/90后）、性别与个性签名等信息。
* **主要涉及文件**：
  * `Guozaoke/ViewModel/PostDetailParser.swift`
  * `Guozaoke/ViewModel/UserInfoParser.swift`
  * `Guozaoke/ViewModel/PostListParser.swift`
  * `Guozaoke/View/Home/PostRowView.swift`
  * `Guozaoke/View/Home/Detail/PostDetailContent.swift`
  * `Guozaoke/View/UserInfoView.swift`

### 3. 个人主页与详情页 404 修复
* **背景与问题**：
  * 用户反映在帖子详情中点击顶部作者头像无法进入个人主页（报 404）。
* **原因分析**：
  * 网页版更新后在 `span.username` 内部紧贴了 `<a class="gzk-credit-level">Lv.3</a>`，原解析器提取出的用户名变成了 `"guozaoke Lv.3"`，导致跳转请求了 `/u/guozaoke%20Lv.3` 造成 404。
* **解决方案**：
  * 解析层优先提取 `a[href^='/u/']` 内部强标签文字或从链接截取真实用户名，并过滤剔除所有 `Lv.` 等级后缀。
  * 在 `UserInfoView` 的 `resolvedUserId` 添加多重清洗容错。

### 4. iPhone Duo 双屏与折叠屏适配
* **新增能力**：
  * 引入 `GKDisplayAdapter.swift`，全局监测并响应折叠屏展开姿势（单屏外屏、展开双屏 Book/Tabletop/Flat 模式）。
  * 针对铰链区域（Hinge）进行避让布局，优化分屏下的 NavigationBar、TabBar 以及双列浏览体验。
* **主要涉及文件**：
  * `Guozaoke/Common/GKDisplayAdapter.swift`
  * `Guozaoke/TabBarView.swift`
  * `Guozaoke/View/Home/PostListView.swift`
  * `Guozaoke/View/Node/NodeListView.swift`

### 5. 桌面小组件 (Widget) 交互强化
* **优化项**：
  * 完善 `PostListWidget` 的时间线刷新机制（`triggerWidgetRefresh`）。
  * 修复小组件直接点击帖子精准唤醒并跳转至对应帖子详情页的路由链路。
* **主要涉及文件**：
  * `PostListWidget/PostListWidget.swift`
  * `Guozaoke/ViewModel/PostListParser.swift`

### 6. 关注功能修复与全场景列表头像用户ID解析强化
* **关注失效根因与修复**：
  * 网页改版后，个人主页关注按钮从旧版的 `.label.label-success` 升级为 `.gzk-profile-follow a`（或 `a[href^='/f/user/']`），原选择器返回 `nil` 导致 `followLink` 为空，点击无反应。
  * 修复：适配 `.gzk-profile-follow a, .label.label-success a, a[href^='/f/user/']` 选择器，并增加 `/f/user/\(username)` 强保底逻辑；同时完善 `NetworkManager` 对 `/f/` 开头的相对路径补全。
  * **关注去冗余刷新**：关注/取关成功后仅局部更新按钮文字状态（`followText` / `followLink`）与成功 Toast，去除了多余的 `fetchUserInfoAndData(..., reset: true)` 全量重载，避免主题列表闪烁与重置。
* **列表头像进入个人主页无法获取信息根因与修复**：
  * 原帖子列表解析器（`PostListParser` 和 `UserInfoParser`）仅通过 `element.select("span.username a").text()` 读取作者，在新版网页中遇到结构变动或内嵌微标时提取为空，导致传入 `UserInfoView` 的用户 ID 丢失。
  * 修复：在首页列表、节点列表、回复列表以及通知列表中，增加多层级用户名精准提取机制，优先以包裹头像的 `<a href="/u/{username}"><img class="avatar"></a>` 兜底；清洗所有前缀 `/u/`、后缀 `Lv.` 与空白；并在 `UserInfoView` 中增加全局 ID 安全转换与容错刷新。
  * 修复消息通知页（`NotificationsView`）头像被隐藏嵌套 `NavigationStack` 遮罩导致无法跳转的问题。
* **主要涉及文件**：
  * `Guozaoke/ViewModel/UserInfoParser.swift`
  * `Guozaoke/ViewModel/PostListParser.swift`
  * `Guozaoke/ViewModel/PostDetailParser.swift`
  * `Guozaoke/ViewModel/NotificationsParser.swift`
  * `Guozaoke/View/UserInfoView.swift`
  * `Guozaoke/View/NotificationsView.swift`
  * `Guozaoke/APIService/NetworkManager.swift`

### 7. 点赞 403 修复与信用等级展示去重
* **点赞 403 根因与修复**：
  * **根因 1（CSRF Token 失效）**：Tornado 框架对 POST 请求进行严格的 CSRF 检验（比对 POST 表单 `_xsrf` 与 HTTP Cookie `_xsrf`）。原代码优先读取登录持久化的静态 `AccountState.token()`，未优先读取实时 Cookie，导致 Cookie 刷新后因 Token 不一致被服务端直接拦截为 403。
  * **根因 2（缺少同源防跨站请求头）**：过早客受 Tengine/WAF 保护，敏感操作 POST 校验必须携带 `Origin: https://www.guozaoke.com`、`Referer` 以及 `X-Xsrftoken`。
  * **修复**：
    * `AccountState.token()` 改为优先从当前的 `HTTPCookieStorage` / App Groups 共享 Cookie 中动态获取最新 `_xsrf`。
    * `NetworkManager.swift` 为所有 POST 请求默认补齐 `Origin: https://www.guozaoke.com` 和 `X-Xsrftoken`。
    * `PostDetailParser.swift` 点赞与回复点赞补全精准 `Referer`（对应帖子详情链接）、`X-Requested-With: XMLHttpRequest` 以及 `data-id` / `data-reply-id` 的 fallback 路由。
* **个人主页信用与等级展示去重**：
  * 个人主页资料选项卡中，原逻辑既插入了 `等级: Lv.3（信用等级 Lv.3；信用 1262）`，又在首行插入了 `信用: 1262`，导致顶部重复出现两条信用数据。
  * 修复：当解析到等级（等级中已包含详细信用说明）时，自动跳过单独的“信用”行，保留统一、规整的等级信用呈现。
* **主要涉及文件**：
  * `Guozaoke/Manager/AccountState.swift`
  * `Guozaoke/APIService/NetworkManager.swift`
  * `Guozaoke/ViewModel/PostDetailParser.swift`
  * `Guozaoke/ViewModel/UserInfoParser.swift`

---

## 历史发布版本记录

### [v1.5.6] - 2025-09-28
- **修复**：小组件点击精准跳转帖子详情页。
- **UI 优化**：引入 `LiquidGlassView` 液态玻璃质感效果。
- **交互**：优化帖子底部评论输入框与全局评论唤起交互。

### [v1.5.5] - 2025-09-17
- **系统适配**：适配 iOS 26 新特性与系统行为变更。

### [v1.5.4] - 2025-08-20
- **优化**：优化网络请求与页面滑动流畅度，修复部分崩溃隐患。

### [v1.5.3] - 2025-08-10
- **功能**：新增开源地址跳转与相关链接主题信息。
- **修复**：修复设置中心 Base64 解码问题。

### [v1.5.2] - 2025-07-28
- **解析优化**：增强对正文和回复中 Email、手机号以及 Node Tag 的高亮与点击解析。

### [v1.5.1] - 2025-07-15
- **功能**：新增内购（In-App Purchase / IAP）支持赞助开发者。

### [v1.5.0] - 2025-06-25
- **功能**：新增字体风格（`fontStyle`）自定义设置。
- **功能**：新增用户屏蔽列表（黑名单）机制，过滤不感兴趣或不良用户的言论。
- **功能**：新增搜索关键词拷贝、加密/解密小工具。

### [v1.1.0 ~ v1.3.0]
- **交互**：优化详情页返回与 TabBar 动态隐藏逻辑。
- **解析**：完善节点分类加载与发帖时间解析。

### [v1.0.0]
- **首次发布**：
  - 基于 SwiftUI 原生开发，纯声明式 UI 架构。
  - 基于 Alamofire + SwiftSoup 的轻量高效网络抓取与 HTML 解析。
  - 支持首页热议、最新、分类节点浏览、个人主页、回复互动与通知中心。

---

## 核心架构与代码回溯指引

当后续遇到网页版 DOM 变动或接口异常时，可优先定位以下模块：

| 模块类别 | 核心文件路径 | 核心职责与注意事项 |
| :--- | :--- | :--- |
| **网络层 / 反爬** | `Guozaoke/APIService/NetworkManager.swift` | 统一请求、Cookie 同步、User-Agent 模拟、WAF 403 拦截处理 |
| **认证服务** | `Guozaoke/View/Login/LoginService.swift` | 登录表单 POST、Token/Session 维护、登录状态解析 |
| **帖子列表解析** | `Guozaoke/ViewModel/PostListParser.swift` | 首页各 Tab 的 HTML 解析、置顶帖/精华帖识别、Widget 刷新触发 |
| **帖子详情解析** | `Guozaoke/ViewModel/PostDetailParser.swift` | 楼主信息、等级、在线状态、楼层评论列表及分页解析 |
| **用户主页解析** | `Guozaoke/ViewModel/UserInfoParser.swift` | 个人资料提取（UID、注册时间、等级积分、个性签名、发帖/回帖记录） |
| **双屏/折叠屏适配** | `Guozaoke/Common/GKDisplayAdapter.swift` | 铰链位置检测、屏幕姿态监听、分屏跨屏布局自适应 |
| **桌面小组件** | `PostListWidget/PostListWidget.swift` | WidgetKit 渲染、TimelineProvider、深度链接跳转 Scheme |
