import SwiftUI

struct FontSizePreviewView: View {
    
    @State private var selectedFontName: String  = UserDefaultsKeys.settingFontName
    @State private var selectedFontSize: CGFloat = UserDefaultsKeys.settingFontSize
    private let minFontSize: CGFloat = 15.0
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
                ListPreviewView(content: AppInfo.appIntro, info: AppInfo.appName, fontSize: $selectedFontSize, fontName: $selectedFontName)
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
        .navigationTitleStyle("字体预览")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: {
                }) {
                    Menu {
                        Button {
                            selectedFontName = UserDefaultsKeys.fontName
                            selectedFontSize = UserDefaultsKeys.fontSize16
                        } label: {
                            Text("默认")
                        }
                        
                        Button {
                            selectedFontName = UserDefaultsKeys.pingFangSCThin
                            selectedFontSize = UserDefaultsKeys.fontSize16
                        } label: {
                            Text(UserDefaultsKeys.pingFangSCThin)
                        }
                        
                        Button {
                            selectedFontName = UserDefaultsKeys.pingFangSCLight
                            selectedFontSize = UserDefaultsKeys.fontSize16
                        } label: {
                            Text(UserDefaultsKeys.pingFangSCLight)
                        }
                        
                        Button {
                            selectedFontName = UserDefaultsKeys.pingFangSCMedium
                            selectedFontSize = UserDefaultsKeys.fontSize16
                        } label: {
                            Text(UserDefaultsKeys.pingFangSCMedium)
                        }
                        
                        Button {
                            selectedFontName = UserDefaultsKeys.pingFangSCRegular
                            selectedFontSize = UserDefaultsKeys.fontSize16
                        } label: {
                            Text(UserDefaultsKeys.pingFangSCRegular)
                            .font(.custom(selectedFontName, size: selectedFontSize))
                        }
                    }
                    label: {
                        Text("推荐")
                            .subTitleFontStyle()
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .padding()
        .onAppear {
            //selectedFontName = UserDefaultsKeys.settingFontName
            //selectedFontSize = UserDefaultsKeys.settingFontSize
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
            ToastView.successToast("保存成功")
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
