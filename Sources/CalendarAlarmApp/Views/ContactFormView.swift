#if canImport(UIKit)
import SwiftUI

struct ContactFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var category: ContactIssueService.Category = .bug
    @State private var subject  = ""
    @State private var email    = ""
    @State private var message  = ""

    @State private var isSubmitting = false
    @State private var result: ContactFormView.SubmitResult?

    private var isValid: Bool {
        !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("カテゴリ") {
                    Picker("カテゴリ", selection: $category) {
                        ForEach(ContactIssueService.Category.allCases, id: \.self) { c in
                            Text(c.label).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("件名") {
                    TextField("例：アラームが鳴らない", text: $subject)
                        .autocorrectionDisabled()
                }

                Section("メールアドレス（任意）") {
                    TextField("返信が必要な場合は入力してください", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("内容") {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .padding(.trailing, 8)
                            }
                            Text(isSubmitting ? "送信中…" : "送信する")
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
            .navigationTitle("お問合わせ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert(item: $result) { r in
                switch r {
                case .success(let number, let url):
                    return Alert(
                        title: Text("送信しました"),
                        message: Text("Issue #\(number) として受け付けました。\n\(url)"),
                        dismissButton: .default(Text("OK")) { dismiss() }
                    )
                case .failure(let message):
                    return Alert(
                        title: Text("送信失敗"),
                        message: Text(message),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response = try await ContactIssueService.submit(
                category: category,
                subject:  subject,
                email:    email,
                message:  message
            )
            result = .success(number: response.number, url: response.url)
        } catch {
            result = .failure(error.localizedDescription)
        }
    }

    enum SubmitResult: Identifiable {
        case success(number: Int, url: String)
        case failure(String)

        var id: String {
            switch self {
            case .success(let n, _): return "success-\(n)"
            case .failure(let m):    return "failure-\(m)"
            }
        }
    }
}

#Preview {
    ContactFormView()
}
#endif
