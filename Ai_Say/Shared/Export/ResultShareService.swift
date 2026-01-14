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
}