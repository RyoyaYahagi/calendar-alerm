#if canImport(UIKit)
import SwiftUI

struct ConnectGoogleView: View {
    @Environment(GoogleAuthController.self) private var auth

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 72))
                .foregroundStyle(.accent)

            VStack(spacing: 12) {
                Text("Googleカレンダーを連携")
                    .font(.title2.bold())

                Text("Googleカレンダーの予定を取得して、キーワードに一致する予定のアラームを自動設定します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                auth.signIn()
            } label: {
                Label("Googleでサインイン", systemImage: "person.crop.circle.badge.plus")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationTitle("Google連携")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ConnectGoogleView()
            .environment(GoogleAuthController())
    }
}
#endif
