import QuickLook
import QuickLookUI
import CoreGraphics

class PreviewProvider: QLPreviewProvider, QLPreviewingController {

    func providePreview(for request: QLFilePreviewRequest) async throws -> QLPreviewReply {
        let fileURL = request.fileURL
        let isAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let width: CGFloat = 1200
        let height: CGFloat = 800
        let contextSize = CGSize(width: width, height: height)

        // STEP files get the lightweight isometric point-cloud preview (MAS-63);
        // DXF/.stch use the vector renderer.
        let ext = fileURL.pathExtension.lowercased()
        let image = (ext == "step" || ext == "stp")
            ? renderStepToImage(url: fileURL, size: contextSize)
            : renderFileToImage(url: fileURL, size: contextSize)

        return QLPreviewReply(contextSize: contextSize, isBitmap: true) { context, _ in
            context.setFillColor(CGColor(gray: 1.0, alpha: 1.0))
            context.fill(CGRect(origin: .zero, size: contextSize))

            guard let image else { return }
            let imgSize = CGSize(width: image.width, height: image.height)
            let scale = min(width / imgSize.width, height / imgSize.height)
            let target = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
            let rect = CGRect(
                x: (width - target.width) / 2,
                y: (height - target.height) / 2,
                width: target.width,
                height: target.height
            )
            context.draw(image, in: rect)
        }
    }
}
