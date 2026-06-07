// safe UIImage <-> Data conversion
//
// I like wrapping this in a tiny codec so image persistence stays explicit and bad payloads fail cleanly.

import UIKit

enum AvatarCodecError: Error {
    case failedToEncodeJPEG
    case failedToDecodeImage
}

struct AvatarCodec {
    func encode(_ image: UIImage, compressionQuality: CGFloat = 0.82) throws -> Data {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            throw AvatarCodecError.failedToEncodeJPEG
        }
        return data
    }

    func decode(_ data: Data) throws -> UIImage {
        guard let image = UIImage(data: data) else {
            throw AvatarCodecError.failedToDecodeImage
        }
        return image
    }
}

let renderer = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40))
let sourceImage = renderer.image { context in
    UIColor.systemIndigo.setFill()
    context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
}

let codec = AvatarCodec()

do {
    let data = try codec.encode(sourceImage)
    let restored = try codec.decode(data)

    // I log both byte size and dimensions when debugging cache issues or corrupted disk payloads.
    print("bytes: \(data.count)")
    print("size: \(Int(restored.size.width))x\(Int(restored.size.height))")
} catch {
    print("avatar codec failed: \(error)")
}
