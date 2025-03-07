import SwiftUI

// MARK: - UserDefaultsKeys


let titleFontName = UserDefaultsKeys.settingFontName

let headFontSize = titleFontSize + 2
/// 推送字体大小
let subTitleFontSize = titleFontSize-2

/// 标题、回复字体大小
let titleFontSize = UserDefaultsKeys.settingFontSize


let usernameFontSize = 13.0
let menuFontSize = 15.0

struct UserDefaultsKeys {
    static let pushNotificationsEnabled = "pushNotificationsEnabled"
    static let hapticFeedbackEnabled    = "hapticFeedbackEnabled"
    static let homeListRefreshEnabled   = "homeListRefreshEnabled"
    static let fontSizeKey = "fontSizeKey"
    static let fontNameKey = "fontNameKey"
    /// 18
    static let fontSize16  = 18.0
    static let fontName    = UIFont.systemFont(ofSize: settingFontSize).fontName
    
    static var shouldSendPushNotification: Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.pushNotificationsEnabled)
    }
    
    static var homeListRefresh: Bool {
        return UserDefaults.standard.bool(forKey: UserDefaultsKeys.homeListRefreshEnabled)
    }
    
    static var settingFontSize: CGFloat {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.fontSizeKey) as? CGFloat ?? fontSize16
    }
    
    static var settingFontName: String {
        return UserDefaults.standard.object(forKey: UserDefaultsKeys.fontNameKey) as? String ?? fontName
    }

}


struct FontSizePreviewView: View {
    
    @State private var selectedFontName: String = UserDefaultsKeys.settingFontName
    @State private var selectedFontSize: CGFloat = UserDefaultsKeys.settingFontSize
    //UserDefaults.standard.object(forKey: UserDefaultsKeys.fontSizeKey) as? CGFloat ?? UserDefaultsKeys.fontSize16
    //UserDefaults.standard.string(forKey: UserDefaultsKeys.fontNameKey) ?? UIFont.systemFont(ofSize: UserDefaultsKeys.fontSize16).fontName
    private let minFontSize: CGFloat = 10.0
    private let maxFontSize: CGFloat = 30.0
    
    private var allFontNames: [String] {
         var fontNames = [String]()
         for family in UIFont.familyNames {
             fontNames.append(contentsOf: UIFont.fontNames(forFamilyName: family))
         }
         return fontNames.sorted()
     }

    var body: some View {
        VStack {
            ScrollView {
                ListPreviewView(content: GuozaokeAppInfo.appIntro, info: GuozaokeAppInfo.appName, fontSize: $selectedFontSize, fontName: $selectedFontName)
                .padding()
                
                Slider(value: $selectedFontSize, in: minFontSize...maxFontSize, step: 1)
                    .padding()

                HStack {
                    Text("字体大小:")
                        .font(.custom(selectedFontName, size: selectedFontSize))
                    Text("\(Int(selectedFontSize))")
                        .font(.custom(selectedFontName, size: selectedFontSize))
                }
                .padding()
                
                
                 Picker("字体样式", selection: $selectedFontName) {
                     ForEach(allFontNames, id: \.self) { fontName in
                         Text(fontName).font(.custom(fontName, size: 16)).tag(fontName)
                     }
                 }
                 .pickerStyle(WheelPickerStyle())
                 .padding()

                Button(action: {
                    saveFont()
                }) {
                    Text("保存设置")
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }

                Spacer()
            }
        }
        .customToolbarTitle("字体预览", fontName: selectedFontName, fontSize: headFontSize, weight: .bold)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                    selectedFontName = UserDefaultsKeys.fontName
                    selectedFontSize = UserDefaultsKeys.fontSize16
                    saveFont()
                }) {
                    Text("默认")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .padding()
        .onAppear {
            selectedFontName = UserDefaultsKeys.settingFontName
            selectedFontSize = UserDefaultsKeys.settingFontSize
            log("[font][size][name] selectedFontName \(selectedFontName) selectedFontSize \(selectedFontSize)")
        }
    }
    
    private func saveFont() {
        var success = false
        if selectedFontName != titleFontName {
            UserDefaults.standard.set(selectedFontName, forKey: UserDefaultsKeys.fontNameKey)
            success = true
        }
        if selectedFontSize != titleFontSize {
            UserDefaults.standard.set(selectedFontSize, forKey: UserDefaultsKeys.fontSizeKey)
            success = true
        }
        if success {
            ToastView.toastText("保存成功")
        }
    }
}


struct ListPreviewView: View {
    let content: String
    let info: String
    let tag: String? = "IT技术"
    @Binding var fontSize: CGFloat
    @Binding var fontName: String

    var body: some View {
        HStack(alignment: .top) {
            KFImageView(AccountState.avatarUrl)
                .avatar()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(content)
                        .font(.custom(fontName, size: fontSize))
                        .padding(.horizontal, 2)
                }
                
                HStack {
                    Text(info)
                        .font(.footnote)
                        .padding(.horizontal, 2)
                    if let tag = tag {
                        Text(tag)
                            .foregroundColor(.blue)
                            .font(.footnote)
                            .clipShape(Rectangle())
                    }
                }
            }
        }

    }
}


//struct FontSizePreviewView_Previews: PreviewProvider {
//    static var previews: some View {
//        FontSizePreviewView()
//    }
//}
