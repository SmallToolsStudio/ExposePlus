import CoreGraphics

/// Geometry for the Mission Control close dot. All rects/points are in global top-left-origin coordinates.
public enum CloseDotPolicy {
    public static let dotSize: CGFloat = 20
    public static let hitSize: CGFloat = 30
    public static let inset: CGFloat = 2

    /// Dot centre: just inside the thumbnail's top-left corner, so the dot hangs half outside it.
    public static func dotCenter(thumbnail: CGRect) -> CGPoint {
        CGPoint(x: thumbnail.minX + inset, y: thumbnail.minY + inset)
    }

    /// Clickable area around the dot (also the panel size).
    public static func dotHitRect(thumbnail: CGRect) -> CGRect {
        let c = dotCenter(thumbnail: thumbnail)
        return CGRect(x: c.x - hitSize / 2, y: c.y - hitSize / 2, width: hitSize, height: hitSize)
    }

    public static func isOverThumbnailOrDot(cursor: CGPoint, thumbnail: CGRect) -> Bool {
        thumbnail.contains(cursor) || dotHitRect(thumbnail: thumbnail).contains(cursor)
    }
}
