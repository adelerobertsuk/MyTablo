import SwiftUI
import WidgetKit
import UIKit
import ImageIO

/// Shared App Group copy so the widget target can find the table picture
/// without importing the app entry point.
private let widgetAppGroupID = "group.com.adeleroberts.ReadingTable"
private let widgetSnapshotFileName = "table-widget.jpg"

enum WidgetSnapshot {
    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: widgetAppGroupID)?
            .appendingPathComponent(widgetSnapshotFileName)
    }

    static func publish(_ image: UIImage) {
        guard let fileURL else { return }
        let maxPixel: CGFloat = 900
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxPixel && longest > 0 ? maxPixel / longest : 1
        let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        guard drawSize.width > 1, drawSize.height > 1 else { return }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let flattened = UIGraphicsImageRenderer(size: drawSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: drawSize))
        }
        try? flattened.jpegData(compressionQuality: 0.82)?.write(to: fileURL, options: .atomic)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func loadImage() -> UIImage? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 900,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Home-screen widget: the same picture as Share, shown in full.
struct TableWidgetView: View {
    let tableImage: UIImage?
    private let palette = Palette.light

    var body: some View {
        ZStack {
            palette.bg
            if let tableImage {
                Image(uiImage: tableImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            }
        }
    }
}

#Preview("Table") {
    TableWidgetView(tableImage: nil)
        .frame(width: 338, height: 158)
}
