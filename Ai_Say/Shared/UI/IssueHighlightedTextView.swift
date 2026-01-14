import SwiftUI
import UIKit

/// SwiftUI 包一层 UITextView：
/// - 渲染高亮富文本
/// - 点击某个 issue 区间，通过自定义 URL scheme 回调给 SwiftUI
struct IssueHighlightedTextView: UIViewRepresentable {
    let text: String
    let issues: [Issue]
    var onTapIssue: (Issue) -> Void

    // 主题（M3 风格：少阴影，靠色调层级）
    var highlightBackground: UIColor = UIColor.systemRed.withAlphaComponent(0.12)
    var highlightUnderline: UIColor = UIColor.systemRed
    var textColor: UIColor = .label
    var baseFont: UIFont = .preferredFont(forTextStyle: .body)

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator

        // 让 link 看起来不像蓝色超链接（更像标注）
        tv.linkTextAttributes = [
            .foregroundColor: textColor,
            .underlineColor: highlightUnderline,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        return tv
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = buildAttributedText()
        uiView.textColor = textColor
        uiView.font = baseFont
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(issues: issues, onTapIssue: onTapIssue)
    }

    // MARK: - Attributed Builder
    private func buildAttributedText() -> NSAttributedString {
        let base = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont,
                .foregroundColor: textColor
            ]
        )

        // 依次给 issue 上样式，并添加"可点击链接"
        for issue in issues {
            guard let r = IssueRangeMapper.nsRangeFromUTF16Offset(text, offset: issue.offset, length: issue.length) else {
                continue
            }
            guard r.location != NSNotFound, r.length > 0, NSMaxRange(r) <= base.length else {
                continue
            }

            // 背景 + 下划线
            base.addAttributes([
                .backgroundColor: highlightBackground,
                .underlineColor: highlightUnderline,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: r)

            // 关键：用 link 来捕获点击
            // 用 issue.id 作为 token
            if let url = URL(string: "aisay-issue://\(issue.id)") {
                base.addAttribute(.link, value: url, range: r)
            }
        }

        return base
    }

    // MARK: - Coordinator
    final class Coordinator: NSObject, UITextViewDelegate {
        private let issues: [Issue]
        private let onTapIssue: (Issue) -> Void

        init(issues: [Issue], onTapIssue: @escaping (Issue) -> Void) {
            self.issues = issues
            self.onTapIssue = onTapIssue
        }

        func textView(
            _ textView: UITextView,
            shouldInteractWith URL: URL,
            in characterRange: NSRange,
            interaction: UITextItemInteraction
        ) -> Bool {
            guard URL.scheme == "aisay-issue" else { return true }
            let token = URL.host ?? ""   // aisay-issue://<token> -> host
            if let hit = issues.first(where: { $0.id == token }) {
                onTapIssue(hit)
            }
            return false // 拦截默认行为
        }
    }
}