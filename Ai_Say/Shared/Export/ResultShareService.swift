import SwiftUI
import UIKit

@MainActor
enum ResultShareService {
    static func renderReport(
        title: String,
        resp: TextEvalResp,
        dimensions: [RadarDimension],
        scale: CGFloat = 2.0
    ) -> UIImage? {
        let view = ReportCardView(
            title: title,
            date: Date(),
            resp: resp,
            dimensions: dimensions
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        renderer.isOpaque = true // 导出更干净

        return renderer.uiImage
    }

    // ✅ audioUrl 拼接（相对路径）
    static func resolveAudioURL(baseURL: String, audioPath: String) -> URL? {
        if audioPath.hasPrefix("http") { return URL(string: audioPath) }
        return URL(string: baseURL + audioPath)
    }
}