import QuickLookThumbnailing
import CoreGraphics
import Cocoa

class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(for request: QLFileThumbnailRequest, _ handler: @escaping (QLThumbnailReply?, Error?) -> Void) {
        let fileURL = request.fileURL

        // Per-format Finder thumbnail toggle (MAS-155). When off, decline so
        // Finder shows the generic file icon instead.
        guard QuickLookPreviewSettings.isEnabled(forExtension: fileURL.pathExtension) else {
            handler(nil, nil)
            return
        }

        let isAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        // Render the file (.stch embedded preview, or freshly-framed DXF) to a
        // black-on-white bitmap sized generously, then blit it aspect-fit into the
        // thumbnail context so it stays crisp when downscaled to a Finder icon.
        //
        // Square canvas (not the old 1200×800): Finder icon tiles are square, so a
        // wide render got letterboxed and the part filled barely half the tile —
        // it read as small and off-centre. A square source aspect-fits to fill the
        // tile, so the part lands centred and as large as its own margin allows.
        let renderSize = CGSize(width: 1024, height: 1024)
        // STEP files get the lightweight isometric point-cloud preview (MAS-63);
        // everything else uses the DXF/.stch renderer.
        let ext = fileURL.pathExtension.lowercased()
        let image: CGImage?
        if ext == "step" || ext == "stp" {
            // Real tessellated mesh (foxtrot) when possible; fall back to the
            // lightweight point-cloud bitmap otherwise (MAS-157).
            if let mesh = loadStepMesh(url: fileURL) {
                image = renderStepMeshToImage(mesh, size: renderSize)
            } else {
                image = renderStepToImage(url: fileURL, size: renderSize)
            }
        } else {
            image = renderFileToImage(url: fileURL, size: renderSize)
        }
        guard let image = image else {
            handler(nil, nil)
            return
        }

        let reply = QLThumbnailReply(contextSize: request.maximumSize) { context in
            let rect = CGRect(origin: .zero, size: request.maximumSize)
            let imgSize = CGSize(width: image.width, height: image.height)
            let scale = min(rect.width / imgSize.width, rect.height / imgSize.height)
            let target = CGSize(width: imgSize.width * scale, height: imgSize.height * scale)
            let targetRect = CGRect(
                x: (rect.width - target.width) / 2,
                y: (rect.height - target.height) / 2,
                width: target.width,
                height: target.height
            )
            context.draw(image, in: targetRect)
            return true
        }

        handler(reply, nil)
    }
}
