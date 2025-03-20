#### Guozaoke iOS
过早客 iOS 「非官方」



<a href="https://apps.apple.com/id6740704728" target="_blank">
    <img src="screenshot/appstore.png" alt="Guozaoke Button" style="width: 150px; height: auto;"></a>

#### ![过早客](screenshot/0308guozaokeinfo.png)

[过早客Android](https://github.com/mzlogin/guanggoo-android/releases)

#### 介绍

[guozaoke.com](guozaoke.com)

[接口参考](https://github.com/mzlogin/guanggoo-android/blob/master/docs/guanggoo-api.md)

#### TODO

目前还有部分内容没有完成等优化处理

* [ ] 支持第三方上传图片，发布主题和评论
* [ ]  再次编辑主题和回复，发帖前支持预览，目前使用HTML解析主题详情
* [ ] 部分解析优化，比如主题详情和评论中email显示问题
* [ ] 支持更换ICON
* [ ] 回复内容UI参考小红书评论实现
* [ ] 更换主题颜色「图片ICON颜色」，iOS 默认系统蓝色
* [ ] Universal Links 如果guozaoke.com 可以配置这里就可以支持跳转个人详情，主题详情，甚至节点详情
* [ ] 好像没有key标识主题已读，但web会显示已读主题
* [ ] 评论或发布主题会出现403，尤其是先登录了App，再登录web，App发布操作就容易403
* [ ] 优化其他内容
* [x] 登录界面添加「网页注册和忘记密码」，之前被Apple拒绝多次，由于没有注销账号功能，暂时不添加

#### Guozaoke 采用SwiftUI编写

使用 [Alamofire](https://github.com/Alamofire/Alamofire) 封装请求

使用 [SwiftSoup](https://github.com/scinfu/SwiftSoup) 解析HTML标签

使用 [RichText](https://github.com/NuPlay/RichText) 解析主题内容

使用 [Kingfisher](https://github.com/onevcat/Kingfisher) 加载图片

使用 [JDStatusBarNotification](https://github.com/calimarkus/JDStatusBarNotification) toast 提示

解析所有节点标签布局参考[graycreate](https://github.com/v2er-app/iOS)部分实现

App ICON由[caipod](https://github.com/caipod) 设计，还有ICON，后续支持更换ICON。

感谢各位！

https://mastergo.com/goto/HNxgmh1Q?page_id=5:00&file=153231050152995

#### 注意

请不要将此工程再次**打包上传到App Store**，仅供参考学习，其实也没啥。

欢迎PR，反馈，新的想法。

#### 愿景

无论你身处何方都可以通过「过早客」关注武汉发展。

希望「过早客」App可以带给你一些有价值的信息，大家都可以使用过早客客户端。

#### 协议

MIT
