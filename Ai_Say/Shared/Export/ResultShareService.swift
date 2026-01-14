import SwiftUI
import UIKit

@MainActor
enum ResultShareService {
    static func renderReport(
        title: String,
        resp: TextEvalResp,
        dimensions: [RadarDimension]
    ) -> UIImage? {
        let view = ReportCardView(
            title: title,
            date: Date(),
            resp: resp,
            dimensions: dimensions
        )

        let renderer = ImageRenderer(content: view)
        renderer.scale = UIScreen.main.scale
        renderer.isOpaque = true // 导出更干净

        return renderer.uiImage
    }
}