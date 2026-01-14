import Foundation

struct Scenario: Identifiable, Hashable {
    enum Level: String, CaseIterable {
        case beginner = "初级"
        case intermediate = "中级"
        case advanced = "高级"
    }

    let id: UUID
    let title: String
    let subtitle: String
    let level: Level
    let minutes: Int
    let tags: [String]
    let prompts: [String]

    // 仅用于瀑布流：模拟卡片高度差（MVP 先用固定规则）
    let heightClass: Int

    static let samples: [Scenario] = [
        .init(
            id: UUID(),
            title: "面试模拟",
            subtitle: "自我介绍 + 项目追问",
            level: .intermediate,
            minutes: 8,
            tags: ["面试", "自我介绍", "项目"],
            prompts: [
                "Please introduce yourself briefly.",
                "Describe a project you are proud of.",
                "What challenge did you face and how did you solve it?"
            ],
            heightClass: 2
        ),
        .init(
            id: UUID(),
            title: "旅行机场",
            subtitle: "值机、安检、登机沟通",
            level: .beginner,
            minutes: 6,
            tags: ["旅行", "机场", "问路"],
            prompts: [
                "Where is the check-in counter?",
                "Could you help me find Gate A12?",
                "My baggage is overweight, what can I do?"
            ],
            heightClass: 1
        ),
        .init(
            id: UUID(),
            title: "咖啡店点单",
            subtitle: "口味偏好 + 追加需求",
            level: .beginner,
            minutes: 5,
            tags: ["日常", "点单", "礼貌表达"],
            prompts: [
                "I'd like a latte, please.",
                "Can I get it with less sugar?",
                "Could you make it iced?"
            ],
            heightClass: 1
        ),
        .init(
            id: UUID(),
            title: "学术讨论",
            subtitle: "表达观点 + 反驳与让步",
            level: .advanced,
            minutes: 10,
            tags: ["学术", "观点", "辩论"],
            prompts: [
                "What is your opinion on AI in education?",
                "Provide one argument and one counterargument.",
                "Summarize your stance in one minute."
            ],
            heightClass: 3
        ),
        .init(
            id: UUID(),
            title: "社交寒暄",
            subtitle: "破冰、兴趣、约时间",
            level: .intermediate,
            minutes: 7,
            tags: ["社交", "small talk"],
            prompts: [
                "How's your day going?",
                "What do you do in your free time?",
                "Would you like to grab coffee sometime?"
            ],
            heightClass: 2
        )
    ]
}