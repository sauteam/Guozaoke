//
//  CommunityPointsView.swift
//  Guozaoke
//
//  Created by scy on 2026/11/14.
//

import SwiftUI

struct CommunityPointsView: View {
    @StateObject private var parser = PointsParser()
    @State private var selectedTab: Int = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 顶部：早点与等级资产概览卡片
                pointsHeaderCard
                
                // 合规免责说明条（对审合规护身符）
                complianceNoticeBanner
                
                // 分段选择器
                tabPicker
                
                // 分页内容区
                switch selectedTab {
                case 0:
                    rulesSection
                case 1:
                    levelsSection
                default:
                    ledgerSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("社区早点")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            hapticFeedback()
            await parser.fetchPointsSummary()
            if selectedTab == 2 {
                await parser.fetchLedger()
            }
        }
        .task {
            await parser.fetchPointsSummary()
            await parser.fetchLedger()
        }
    }
    
    // MARK: - 资产概览卡片
    private var pointsHeaderCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.85),
                            Color.red.opacity(0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.orange.opacity(0.25), radius: 8, x: 0, y: 4)
            
            HStack(spacing: 24) {
                // 早点数值
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                        Text("当前社区早点")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.9))
                    
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(parser.pointsBalance)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text("点")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                
                Spacer()
                
                // 信用等级
                VStack(alignment: .trailing, spacing: 6) {
                    Text("信用等级")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                    
                    Text(parser.creditLevel.isEmpty ? "Lv.1" : parser.creditLevel)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.22))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
    }
    
    // MARK: - 合规免责条（明确这是不可交易的社区贡献激励）
    private var complianceNoticeBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.shield")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
                .padding(.top, 1)
            
            Text("早点为过早客社区活跃度激励，仅通过日常发帖与互动获得，不可充值、转让或兑现。")
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineSpacing(2)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
    
    // MARK: - Tab 分段
    private var tabPicker: some View {
        Picker("早点信息分类", selection: $selectedTab) {
            Text("获取规则").tag(0)
            Text("信用等级").tag(1)
            Text("明细记录").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.top, 4)
    }
    
    // MARK: - Tab 0: 获取规则
    private var rulesSection: some View {
        VStack(spacing: 12) {
            ForEach(parser.rules) { rule in
                HStack(spacing: 14) {
                    Image(systemName: rule.iconName)
                        .font(.system(size: 20))
                        .foregroundColor(.orange)
                        .frame(width: 32, height: 32)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text(rule.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                        Text(rule.subtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(rule.reward)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(6)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Tab 1: 信用等级说明
    private var levelsSection: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                // 表头
                HStack {
                    Text("等级")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .leading)
                    
                    Text("信用分区间")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(width: 100, alignment: .leading)
                    
                    Spacer()
                    
                    Text("说明")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                
                Divider()
                
                // 表格内容
                ForEach(parser.creditLevels) { item in
                    HStack {
                        Text(item.level)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.blue)
                            .frame(width: 50, alignment: .leading)
                        
                        Text(item.range)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.primary)
                            .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        Text(item.desc)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    
                    if item != parser.creditLevels.last {
                        Divider().padding(.leading, 14)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            
            Text("注：信用记录长期贡献，早点用于社区内互动激励。历史信用予以保留，规则按社区当前贡献机制评估。")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // MARK: - Tab 2: 积分明细
    private var ledgerSection: some View {
        VStack(spacing: 12) {
            if parser.isLedgerLoading {
                ProgressView("加载明细中...")
                    .padding(.vertical, 32)
            } else if parser.ledgerItems.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.top, 24)
                    
                    Text("暂无明细记录")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Text("积极参与社区发帖、回复互动即可积累早点")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            } else {
                ForEach(parser.ledgerItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.action)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            Text(item.date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(item.pointsChange.isEmpty ? "+1" : item.pointsChange)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(item.pointsChange.contains("-") ? .red : .green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
            }
        }
    }
}
