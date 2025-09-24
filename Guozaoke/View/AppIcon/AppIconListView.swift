import SwiftUI

struct AppIconListView: View {
    @StateObject private var viewModel = AppIconViewModel()
    
    let columns = Array(repeating: GridItem(.flexible()), count: 3)
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                #if targetEnvironment(simulator)
                Text("⚠️ 模拟器提示:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.orange)
                Text("模拟器不支持显示更换的App Icon")
                    .font(.caption)
                    .foregroundColor(.orange)
                Text("请在真机上测试图标切换功能")
                    .font(.caption)
                    .foregroundColor(.orange)
                #else
                Text("调试信息:")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("图标数量: \(AppIconConfig.icons.count)")
                    .font(.caption)
                Text("当前图标: \(viewModel.currentIconName ?? "默认")")
                    .font(.caption)
                Text("支持更换: \(UIApplication.shared.supportsAlternateIcons ? "是" : "否")")
                    .font(.caption)
                #endif
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
            .padding(.horizontal)
            
            if viewModel.isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AppIconConfig.icons) { icon in
                        IconCell(
                            icon: icon,
                            isSelected: viewModel.currentIconName == icon.iconName
                        ) {
                            logger("[DEBUG] 点击图标: \(icon.iconName), 图片: \(icon.iconImage)")
                            viewModel.setAppIcon(to: icon.iconName == "AppIcon" ? nil : icon.iconName)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .navigationTitleStyle("更换图标")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            logger("[DEBUG] AppIconConfig.icons: \(AppIconConfig.icons)")
            for icon in AppIconConfig.icons {
                logger("[DEBUG] 图标: \(icon.iconName), 图片: \(icon.iconImage), 显示名: \(icon.displayName)")
            }
            
            // 检查Bundle中的资源
            logger("[DEBUG] 检查Bundle资源:")
            for icon in AppIconConfig.icons {
                let imageExists = UIImage(named: icon.iconImage) != nil
                logger("[DEBUG] 图片 \(icon.iconImage) 存在: \(imageExists)")
            }
            
            // 测试其他图片资源
            let testImages = ["zao-white", "ZaoDark", "1024", "zaoIcon", "m_default"]
            for testImage in testImages {
                let exists = UIImage(named: testImage) != nil
                logger("[DEBUG] 测试图片 \(testImage) 存在: \(exists)")
            }
            
            // 检查Info.plist配置
            if let iconsDict = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any] {
                logger("[DEBUG] CFBundleIcons配置: \(iconsDict)")
                if let alternateIcons = iconsDict["CFBundleAlternateIcons"] as? [String: Any] {
                    logger("[DEBUG] CFBundleAlternateIcons: \(alternateIcons)")
                }
            }
            
            viewModel.checkCurrentIcon()
        }
    }
}

struct IconCell: View {
    let icon: AppIcon
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // 图标背景
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                    )
                
                // 图标
                #if targetEnvironment(simulator)
                // 模拟器显示占位符
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 60, height: 60)
                    
                    VStack(spacing: 4) {
                        Image(systemName: "app.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("模拟器")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                #else
                // 真机显示实际图标
                Image(icon.iconImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                    .onAppear {
                        logger("[DEBUG] 尝试加载图标: \(icon.iconImage)")
                    }
                #endif
            }
            
            // 图标名称
            Text(icon.displayName)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .blue : .primary)
                .multilineTextAlignment(.center)
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .onTapGesture(perform: onTap)
    }
}

class AppIconViewModel: ObservableObject {
    @Published var currentIconName: String? = nil
    @Published var isLoading = false
    
    func checkCurrentIcon() {
        currentIconName = UIApplication.shared.alternateIconName
    }
    
    func setAppIcon(to iconName: String?) {
        #if targetEnvironment(simulator)
        logger("[AppIcon] 模拟器不支持更换图标，请在真机上测试")
        ToastView.warningToast("模拟器不支持更换图标")
        return
        #endif
        
        guard UIApplication.shared.supportsAlternateIcons else {
            logger("[AppIcon] 当前设备不支持更改图标")
            ToastView.errorToast("当前设备不支持更改图标")
            return
        }
        
        isLoading = true
        
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    logger("[AppIcon] 图标更换失败: \(error.localizedDescription)")
                    ToastView.errorToast("图标更换失败")
                } else {
                    logger("[AppIcon] 图标更换成功!")
                    self?.currentIconName = iconName
                    ToastView.successToast("图标更换成功")
                }
            }
        }
    }
}
