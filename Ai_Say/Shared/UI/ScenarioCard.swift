import SwiftUI

struct ScenarioCard: View {
    let scenario: Scenario

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 图片占位（MVP 不依赖资源）
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.accentColor.opacity(0.12))
                Image(systemName: "sparkles")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(height: coverHeight)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(scenario.title)
                    .font(.headline)

                Text(scenario.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    pill("\(scenario.level.rawValue)")
                    pill("\(scenario.minutes) 分钟")
                }
            }

            // tags（最多两行）
            WrapTags(tags: scenario.tags)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var coverHeight: CGFloat {
        switch scenario.heightClass {
        case 1: return 120
        case 2: return 150
        default: return 180
        }
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(0.10))
            .foregroundStyle(Color.accentColor)
            .clipShape(Capsule())
    }
}

/// 简单标签换行（iPad 足够用）
private struct WrapTags: View {
    let tags: [String]

    var body: some View {
        // 用两行截断的"伪换行"：MVP 快速稳定
        let shown = Array(tags.prefix(6))
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ForEach(shown.prefix(3), id: \.self) { tag in tagChip(tag) }
                Spacer(minLength: 0)
            }
            if shown.count > 3 {
                HStack(spacing: 8) {
                    ForEach(shown.dropFirst(3), id: \.self) { tag in tagChip(tag) }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func tagChip(_ t: String) -> some View {
        Text(t)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(.tertiarySystemBackground))
            .foregroundStyle(.secondary)
            .clipShape(Capsule())
    }
}