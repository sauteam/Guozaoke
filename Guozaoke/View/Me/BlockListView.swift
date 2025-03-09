//
//  BlockListView.swift
//  Guozaoke
//
//  Created by scy on 2025/3/6.
//

import SwiftUI

struct BlockListView: View {
    @StateObject private var viewModel = UserInfoParser()

    var body: some View {
        VStack {
            List {
                
                ForEach(viewModel.memberInfo) {
                    if $0.member.count > 0 {
                        MemberItemView(data: $0)
                    }
                }
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else if viewModel.memberInfo.first?.member.isEmpty == true {
                    HStack {
                        Spacer()
                        Text(NoMoreDataTitle.nodata)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 12)
                }
            }
            .onAppear {
                if !LoginStateChecker.isLogin {
                    LoginStateChecker.LoginStateHandle()
                    return
                }
                if viewModel.memberInfo.isEmpty == true {
                    Task { await viewModel.loadMyBlockList() }
                }
            }
            .refreshable {
                Task { await viewModel.loadMyBlockList() }
            }
        }
        .buttonStyle(.plain)
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitleStyle("屏蔽列表")
    }
}

