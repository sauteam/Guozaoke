//
//  FaqView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/12.
//

import SwiftUI

struct FaqView: View {
    
    let  faqText = """
    广告服务
    过早客是源自武汉的高端社交网络，这里有关于创业、创意、IT、金融等最热话题的交流，也有招聘问答、活动交友等最新资讯的发布。我们希望共同维护一个能吸引用户快速有效交换信息的同城平台，通过线上的简洁体验来丰富便利我们的线下生活。

    做为一个日活超过10万，用户数量持续增长的网络社区，这里汇聚了各行各业的精英和知识分享者，如果您希望您的品牌获得更广泛的影响力和可触达的目标受众，欢迎联系我们的广告合作团队微信：fullygroup50

    我们将为您提供全方位的支持，让您的品牌与优质内容相得益彰，与广大用户建立紧密的联系。


    社区指南
    guozaoke.com的愿景是成为一个内容优质、氛围愉快的轻社区，为了实现这个目标，我们在建立之初约定了以下基本规则：

    社区提倡的
    •鼓励一切原创和注明转载出处的高质量内容，我们相信好东西经得起时间的沉淀而不是风靡一时的传播；
    •鼓励独立思考、理智且不失活泼的回帖，而不是“顶”、“沙发”等毫无营养的回复；
    •鼓励有信息量的讨论，友善的对待每一位参与者；
    •鼓励在提出问题前先进行关键词搜索，同时对于答案及时补充更新，惠及以后提出类似问题的人；

    社区不欢迎的
    •提供虚假信息的帖子；
    •复制粘贴百度知道的回复；
    •滥发广告的ID；
    •容易引起不适的昵称头像；

    社区禁止的
    •触犯法律的行为；
    •损害他人利益的行为；
    •其它危害社区的行为；

    """

    @StateObject private var viewModel = UserInfoParser()

    var body: some View {
        VStack {
            List {
                Text(faqText)
                    .subTitleFontStyle(weight: .thin)
            }
            .listStyle(.plain)
            .listRowSeparator(.hidden)
        }
        .customContextMenu(menuItems: [.copy], onAction: { _ in
            faqText.copyToClipboard()
        })
//        VStack {
//            RichTextView(content: viewModel.faqContent)
//                .padding(.horizontal)
//        }
//        .onAppear() {
//            if viewModel.faqContentValid() == false {
//                Task { await viewModel.faqInfo() }
//            }
//        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitleStyle("Faq")
        .navigationBarTitleDisplayMode(.inline)
    }
}

//#Preview {
//    FaqView()
//}
