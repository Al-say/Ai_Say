import Foundation

/// 每日挑战缓存（UserDefaults）
struct DailyChallengeCache {
    static func key(_ persona: UserPersona) -> String { "dailyChallenge_\(persona.rawValue)" }
    static func dateKey(_ persona: UserPersona) -> String { "dailyChallengeDate_\(persona.rawValue)" }

    static func load(persona: UserPersona) -> DailyChallengeDTO? {
        let ud = UserDefaults.standard
        guard let data = ud.data(forKey: key(persona)),
              let date = ud.object(forKey: dateKey(persona)) as? Date
        else { return nil }

        // 只缓存"当天"
        if !Calendar.current.isDateInToday(date) { return nil }
        return try? JSONDecoder().decode(DailyChallengeDTO.self, from: data)
    }

    static func save(_ dto: DailyChallengeDTO, persona: UserPersona) {
        let ud = UserDefaults.standard
        if let data = try? JSONEncoder().encode(dto) {
            ud.set(data, forKey: key(persona))
            ud.set(Date(), forKey: dateKey(persona))
        }
    }
}