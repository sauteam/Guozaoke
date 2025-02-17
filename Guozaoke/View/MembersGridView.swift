//
//  MembersGridView.swift
//  Guozaoke
//
//  Created by scy on 2025/2/16.
//

let avatarUrl: String = "https://cdn.guozaoke.com//static/avatar/46/s_default.png"

import SwiftUI

struct MembersGridView: View {
    @StateObject private var viewModel = UserInfoParser()

    var body: some View {
        VStack {
            List {
                ForEach(viewModel.memberInfo) {
                    MemberItemView(data: $0)
                }
            }
            .onAppear {
                if viewModel.memberInfo.isEmpty == true {
                    Task { await viewModel.fetchMemberList() }
                }
            }
            .refreshable {
                Task { await viewModel.fetchMemberList() }
            }
        }
        .buttonStyle(.plain)
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .navigationTitle("成员")
    }
}


struct MemberItemView: View {
    let columns = isiPad ? [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ] : [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    let data: MemberInfo
    @State private var showUserInfoView = false
    @State private var selectedNode: Member? = nil

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(data.title)
                        .font(.body)
                        .padding(.horizontal, 20)
                        .foregroundColor(.gray)
                }
                
                Divider()
                
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(data.member) { member in
                        VStack {
                            KFImageView(member.avatar)
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                            Text(member.username)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            showUserInfoView = true
                            selectedNode     = member
                        }
                    }
                }
                .navigationDestination(isPresented: $showUserInfoView) {
                    if let member = selectedNode {
                        UserInfoView(userId: member.username)
                    }
                }
            }
        }
    }
}

