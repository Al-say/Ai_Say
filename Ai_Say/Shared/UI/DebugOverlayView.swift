import SwiftUI

struct DebugOverlayView: View {
    @ObservedObject var store = DebugStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.entries) { e in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(e.endpoint).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text("\(e.status)").font(.caption).monospacedDigit()
                        }
                        if let err = e.error {
                            Text("ERR: \(err)").font(.footnote).foregroundStyle(.red)
                        }
                        Text("RAW: \(e.raw)")
                            .font(.footnote)
                            .textSelection(.enabled)
                            .lineLimit(8)
                    }
                    .padding(.vertical, 6)
                }
            }
            .navigationTitle("Debug")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") { store.clear() }
                }
            }
        }
    }
}