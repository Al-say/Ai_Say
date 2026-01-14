import SwiftUI

struct PromptPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var currentPrompt: String
    let historyPrompts: [String] // 从 HomeView 传入去重后的历史

    let library = ["谈谈你对 AI 的看法", "描述一个你最喜欢的城市", "介绍你的家乡"]

    var body: some View {
        NavigationStack {
            List {
                Section("推荐题库") {
                    ForEach(library, id: \.self) { p in
                        promptRow(p)
                    }
                }

                if !historyPrompts.isEmpty {
                    Section("最近练习") {
                        ForEach(historyPrompts, id: \.self) { p in
                            promptRow(p)
                        }
                    }
                }
            }
            .navigationTitle("更换题目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("关闭") { dismiss() }
            }
        }
    }

    private func promptRow(_ p: String) -> some View {
        Button {
            currentPrompt = p
            dismiss()
        } label: {
            HStack {
                Text(p).foregroundStyle(.primary)
                Spacer()
                if p == currentPrompt {
                    Image(systemName: "checkmark").foregroundColor(.accentColor)
                }
            }
        }
    }
}