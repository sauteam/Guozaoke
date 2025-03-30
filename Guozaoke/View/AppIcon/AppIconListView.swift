import SwiftUI

struct AppIcon: Identifiable {
    let id = UUID()
    let iconName: String
    let iconImage: String
}

// TODO: AppIconListView

struct AppIconListView: View {
    
    //@StateObject private var viewModel = AppIconViewModel()
    
    let columns = Array(repeating: GridItem(.flexible()), count: 4)
    
    var body: some View {
        
        VStack {
//            if viewModel.isLoading {
//                ProgressView("Loading...")
//            } else {
//                LazyVGrid(columns: columns, spacing: 20) {
//                    ForEach(viewModel.icons) { appIcon in
//                        VStack {
//                            Image(appIcon.iconImage)
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 50, height: 50)
//                            Text(appIcon.iconName)
//                                .font(.caption)
//                                .foregroundColor(.gray)
//                        }
//                        .onTapGesture {
//                            setAppIcon(to: appIcon.iconName)
//                        }
//                    }
//                }
//            }
        }
        .onAppear() {
            //viewModel.loadIconsIfNeeded()
        }
        
    }

    func setAppIcon(to iconName: String) {
        if UIApplication.shared.supportsAlternateIcons {
            UIApplication.shared.setAlternateIconName(iconName) { error in
                if let error = error {
                    print("[AppIcon] 图标更换失败: \(error.localizedDescription)")
                } else {
                    print("[AppIcon] 图标更换成功!")
                }
            }
        } else {
            print("[AppIcon] 当前设备不支持更改图标")
        }
    }
}

class AppIconViewModel: ObservableObject {
    @Published var icons: [AppIcon] = []
    @Published var isLoading = false
    
    func loadIconsIfNeeded() {
        guard icons.isEmpty else {
            print("Icons already loaded, skipping.")
            return
        }
        
        isLoading = true
        print("Starting icon loading...")
        
        Task {
            let loadedIcons = await loadIconsFromInfoPlist()
            print("loadedIcons: \(loadedIcons.count) icons.")

            await MainActor.run {
                self.icons = loadedIcons
                self.isLoading = false
                print("success: \(loadedIcons.count) icons.")
                self.objectWillChange.send()
            }
        }
    }

    func loadIconsFromInfoPlist() async -> [AppIcon] {
        //print("Loading icons from Info.plist on background thread: \(Thread.current)")
        
        if let iconsDict = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let alternateIcons = iconsDict["CFBundleAlternateIcons"] as? [String: Any] {
            
            print("Found alternate icons in Info.plist: \(alternateIcons)")
            
            return alternateIcons.compactMap { (iconName, iconInfo) -> AppIcon? in
                guard let iconInfoDict = iconInfo as? [String: Any],
                      let iconFiles = iconInfoDict["CFBundleIconFiles"] as? [String],
                      let iconFile = iconFiles.first else {
                    print("Failed to load icon for \(iconName).")
                    return nil
                }
                
                let appIcon = AppIcon(iconName: iconName, iconImage: iconFile)
                print("Loaded icon: \(appIcon.iconName) with file: \(appIcon.iconImage)")
                return appIcon
            }
        } else {
            print("No alternate icons found in Info.plist.")
            return []
        }
    }
}


//
//class AppIconViewModel: ObservableObject {
//    @Published var icons: [AppIcon] = []
//    @Published var isLoading = false
//    
//    func loadIconsIfNeeded() {
//        guard icons.isEmpty else {
//            print("Icons already loaded, skipping.")
//            return
//        }
//        
//        isLoading = true
//        print("Starting icon loading...")
//        
//        DispatchQueue.global(qos: .background).async {
//            let loadedIcons = self.loadIconsFromInfoPlist()
//            print("loadedIcons: \(loadedIcons.count) icons.")
//            
//            DispatchQueue.main.async {
//                self.icons = loadedIcons
//                self.isLoading = false
//                print("Icons loaded successfully: \(loadedIcons.count) icons.")
//            }
//        }
//    }
//
//    func loadIconsFromInfoPlist() -> [AppIcon] {
//        print("Loading icons from Info.plist on background thread: \(Thread.current)")
//        
//        if let iconsDict = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
//           let alternateIcons = iconsDict["CFBundleAlternateIcons"] as? [String: Any] {
//            
//            print("Found alternate icons in Info.plist: \(alternateIcons)")
//            
//            return alternateIcons.compactMap { (iconName, iconInfo) -> AppIcon? in
//                guard let iconInfoDict = iconInfo as? [String: Any],
//                      let iconFiles = iconInfoDict["CFBundleIconFiles"] as? [String],
//                      let iconFile = iconFiles.first else {
//                    print("Failed to load icon for \(iconName).")
//                    return nil
//                }
//                
//                let appIcon = AppIcon(iconName: iconName, iconImage: iconFile)
//                print("Loaded icon: \(appIcon.iconName) with file: \(appIcon.iconImage)")
//                return appIcon
//            }
//        } else {
//            print("No alternate icons found in Info.plist.")
//            return []
//        }
//    }
//}

//struct AppIconListView: View {
//    @StateObject private var viewModel = AppIconViewModel()
//    
//    let columns = Array(repeating: GridItem(.flexible()), count: 3)
//    private var icons: [AppIcon] = []
//    
//    @State private var isLoading = false
//    
//    var body: some View {
//        VStack(spacing: 16) {
//            Text("1212")
////            if viewModel.isLoading {
////                ProgressView()
////                    .frame(maxWidth: .infinity, maxHeight: .infinity)
////            } else {
////
////            }
//            
////            LazyVGrid(columns: columns, spacing: 20) {
////                ForEach(AppIconConfig.icons) { icon in
////                    IconCell(
////                        icon: icon,
////                        isSelected: viewModel.currentIconName == icon.iconName
////                    ) {
////                        viewModel.setAppIcon(to: icon.iconName == "Default" ? nil : icon.iconName)
////                    }
////                }
////            }
////            .padding()
//        }
//        .navigationTitleStyle("更换图标")
//        .navigationBarTitleDisplayMode(.inline)
//        .onAppear {
//            //viewModel.checkCurrentIcon()
//            
//            loadIconsIfNeeded()
//        }
//    }
//    
//    func loadIconsIfNeeded() {
//        guard icons.isEmpty else { return }
//        
//        isLoading = true
//        
//        DispatchQueue.global(qos: .userInitiated).async { 
//            //guard let self = self else { return }
//            
//            if let iconsDict = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
//               let alternateIcons = iconsDict["CFBundleAlternateIcons"] as? [String: Any] {
//                
//                let loadedIcons = alternateIcons.compactMap { (iconName, iconInfo) -> AppIcon? in
//                    guard let iconInfoDict = iconInfo as? [String: Any],
//                          let iconFiles = iconInfoDict["CFBundleIconFiles"] as? [String],
//                          let iconFile = iconFiles.first else {
//                        return nil
//                    }
//                    return AppIcon(iconName: iconName, iconImage: iconFile, displayName: iconName)
//                }
//                
////                DispatchQueue.main.async {
////                    self.icons = loadedIcons
////                    self.isLoading = false
////                }
//            } else {
//                DispatchQueue.main.async {
//                    self.isLoading = false
//                }
//            }
//        }
//    }
//}
//
//struct IconCell: View {
//    let icon: AppIcon
//    let isSelected: Bool
//    let onTap: () -> Void
//    
//    var body: some View {
//        VStack {
//            Image(icon.iconImage)
//                .resizable()
//                .scaledToFit()
//                .frame(width: 60, height: 60)
//                .cornerRadius(12)
//                .overlay(
//                    RoundedRectangle(cornerRadius: 12)
//                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
//                )
//            
//            Text(icon.displayName)
//                .font(.caption)
//                .foregroundColor(isSelected ? .blue : .gray)
//        }
//        .padding(.vertical, 8)
//        .onTapGesture(perform: onTap)
//    }
//}
//
//class AppIconViewModel: ObservableObject {
//    @Published var isLoading = false
//    @Published var currentIconName: String?
//    
//    func checkCurrentIcon() {
//        //currentIconName = UIApplication.shared.alternateIconName ?? "Default"
//    }
//    
//    func setAppIcon(to iconName: String?) {
//        #if targetEnvironment(simulator)
//        print("[AppIcon] 模拟器不支持更换图标，请在真机上测试")
//        return
//        #endif
//        
//        guard UIApplication.shared.supportsAlternateIcons else {
//            print("[AppIcon] 当前设备不支持更改图标")
//            return
//        }
//        
//        isLoading = true
//        
//        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
//            DispatchQueue.main.async {
//                self?.isLoading = false
//                if let error = error {
//                    print("[AppIcon] 图标更换失败: \(error.localizedDescription)")
//                } else {
//                    print("[AppIcon] 图标更换成功!")
//                    self?.currentIconName = iconName ?? "AppIcon"
//                }
//            }
//        }
//    }
//}
