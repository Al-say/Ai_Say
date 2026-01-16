import SwiftUI

struct ProfileView: View {
    @State private var notificationsEnabled = true
    @State private var darkModeEnabled = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ViewThatFits {
                    // iPad 横屏：双栏布局
                    HStack(alignment: .top, spacing: 24) {
                        VStack(spacing: 24) {
                            profileHeader
                            statsGrid
                        }
                        .frame(maxWidth: 420)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 24) {
                            preferenceSection
                            systemSection
                            supportSection
                        }
                        .frame(maxWidth: 520)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)

                    // 手机竖屏：单栏布局
                    VStack(spacing: 24) {
                        profileHeader
                        statsGrid
                        preferenceSection
                        systemSection
                        supportSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("个人中心")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var profileHeader: some View {
        AppCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("学习者")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("已学习 45 天")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        statItem("总时长", "12.5h")
                        statItem("平均得分", "82")
                        statItem("连续天数", "7")
                    }
                }

                Spacer()
            }
        }
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学习统计").font(.caption).padding(.leading, 8)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                statCard("本周练习", "8 次", .blue)
                statCard("最佳得分", "95", .green)
                statCard("进步幅度", "+12%", .orange)
            }
        }
    }

    private func statCard(_ title: String, _ value: String, _ color: Color) -> some View {
        AppCard {
            VStack(spacing: 8) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    private func statItem(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var preferenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("偏好设置").font(.caption).padding(.leading, 8)

            AppCard {
                VStack(spacing: 0) {
                    PersonaPickerRow()
                    Divider().padding(.leading, 44)
                    M3SettingRow(icon: "target", title: "练习目标", detail: "每日 20 分钟")
                    Divider().padding(.leading, 44)
                    M3SettingRow(icon: "waveform", title: "发音参考", detail: "美式英语")
                }
            }
        }
    }

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系统").font(.caption).padding(.leading, 8)

            AppCard {
                VStack(spacing: 0) {
                    M3SettingRow(icon: "bell", title: "提醒通知", isToggle: true, isOn: $notificationsEnabled)
                    Divider().padding(.leading, 44)
                    M3SettingRow(icon: "moon", title: "深色模式", isToggle: true, isOn: $darkModeEnabled)
                }
            }
        }
    }

    private var supportSection: some View {
        AppCard {
            VStack(spacing: 0) {
                M3SettingRow(icon: "info.circle", title: "关于 Ai_Say", detail: "v1.0.0")
                Divider().padding(.leading, 44)
                M3SettingRow(icon: "rectangle.portrait.and.arrow.right", title: "退出登录", color: .red)
            }
        }
    }
}

struct M3SettingRow: View {
    let icon: String
    let title: String
    var detail: String? = nil
    var isToggle: Bool = false
    var isOn: Binding<Bool>? = nil
    var color: Color = .primary

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24, height: 24)

            Text(title)
                .foregroundStyle(color)

            Spacer()

            if let detail = detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if isToggle, let isOn = isOn {
                Toggle("", isOn: isOn)
                    .labelsHidden()
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}

struct PersonaPickerRow: View {
    @StateObject private var store = PersonaStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("当前模式").font(.subheadline).foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { store.current },
                set: { store.setPersona($0) }
            )) {
                ForEach(UserPersona.allCases, id: \.self) { p in
                    Text(p.title).tag(p)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}