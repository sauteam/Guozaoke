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
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                }
                
                ForEach(viewModel.memberInfo) {
                    MemberItemView(data: $0)
                }
                
                if viewModel.memberInfo.isEmpty {
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
        .navigationTitle("屏蔽列表")
    }
}

