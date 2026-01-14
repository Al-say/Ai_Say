import Foundation
import Combine

@MainActor
final class DebugStore: ObservableObject {
    static let shared = DebugStore()

    struct Entry: Identifiable {
        let id = UUID()
        let time: Date
        let endpoint: String
        let status: Int
        let raw: String
        let error: String?
    }

    @Published private(set) var entries: [Entry] = []

    func push(endpoint: String, status: Int, raw: String, error: String? = nil) {
        entries.insert(.init(time: Date(), endpoint: endpoint, status: status, raw: raw, error: error), at: 0)
        if entries.count > 20 { entries.removeLast(entries.count - 20) }
    }

    func clear() { entries.removeAll() }
}