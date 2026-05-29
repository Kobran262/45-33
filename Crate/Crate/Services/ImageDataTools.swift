import UIKit

enum ImageDataTools {
    static func compressedJPEG(from data: Data, maxSide: CGFloat = 900, quality: CGFloat = 0.74) -> Data {
        guard let image = UIImage(data: data) else { return data }
        return compressedJPEG(from: image, maxSide: maxSide, quality: quality)
    }

    static func compressedJPEG(from image: UIImage, maxSide: CGFloat = 900, quality: CGFloat = 0.74) -> Data {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality) ?? Data()
    }
}
