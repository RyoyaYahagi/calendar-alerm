#if canImport(UIKit)
import SwiftUI

struct SettingsView: View {
    @State private var showContactForm = false

    var body: some View {
        List {
            Section("サポート") {
                Button {
                    showContactForm = true
                } label: {
                    Label("お問合わせ", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("設定")
        .sheet(isPresented: $showContactForm) {
            ContactFormView()
        }
    }
}
#endif
