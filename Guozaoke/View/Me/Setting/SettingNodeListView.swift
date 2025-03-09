import SwiftUI

struct SettingNodeListView: View {
    @StateObject private var viewModel = PostListViewModel()
    
    var body: some View {
        List {
            ForEach(viewModel.postListItems) { item in
                HStack {
                    Text(item.type.rawValue)
                        .titleFontStyle()

                    Spacer()
                    
                    Toggle(isOn: Binding(
                        get: { item.isVisible },
                        set: { newValue in
                            viewModel.setVisibility(forType: item.type, isVisible: newValue)
                        }
                    )) {
                        Text(item.isVisible ? "「显示」": "「不显示」")
                            .subTitleFontStyle(weight: .thin)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(.vertical, 8)
            }
            .onMove(perform: viewModel.movePostListItem)
        }
        .toolbar(.hidden, for: .tabBar)
        .navigationTitleStyle("首页节点顺序")
        .navigationBarItems(trailing: EditButton())
    }
}

#Preview {
    SettingNodeListView()
}
