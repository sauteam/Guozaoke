import SwiftUI

struct SecureTextField: View {
    @Binding var text: String
    @State private var isSecured: Bool = true

    var body: some View {
        HStack {
            if isSecured {
                SecureField("输入密码", text: $text)
                    //.padding()
//                    .background(Color(.secondarySystemBackground))
//                    .cornerRadius(0)
            } else {
                TextField("输入密码", text: $text)
                    //.padding()
                    //.background(Color(.secondarySystemBackground))
                    //.cornerRadius(0)
            }

            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: self.isSecured ? "eye.slash" : "eye")
                    .accentColor(.gray)
            }
        }
    }
}

//struct SecureTextField_Previews: PreviewProvider {
//    @State static var password: String = ""
//    static var previews: some View {
//        SecureTextField(text: $password)
//    }
//}
