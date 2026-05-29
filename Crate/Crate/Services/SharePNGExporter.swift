import SwiftUI
import UIKit

enum SharePNGExporter {
    @MainActor
    static func temporaryPNGURL<Content: View>(
        filename: String,
        width: CGFloat,
        scale: CGFloat = UIScreen.main.scale,
        @ViewBuilder content: () -> Content
    ) -> URL? {
        let renderer = ImageRenderer(content: content().frame(width: width))
        renderer.scale = scale
        renderer.isOpaque = true

        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            return nil
        }

        let safeName = filename
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeName)
            .appendingPathExtension("png")

        do {
            try data.write(to: url, options: [.atomic])
            return url
        } catch {
            return nil
        }
    }
}
