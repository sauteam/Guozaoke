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
    let columns = Array(repeating: GridItem(.flexible()), count: isiPad ? 10: 6)
        
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
                                .avatar(size: 50)
                                .scaledToFit()
                            Text(member.username)
                                .font(.caption)
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                        .onTapGesture {
                            showUserInfoView.toggle()
                            selectedNode     = member
                        }
                    }
                }
            }
        }
        .navigationDestination(isPresented: $showUserInfoView, destination: {
            if let member = selectedNode {
                UserInfoView(userId: member.username)
            }
        })
    }
}

