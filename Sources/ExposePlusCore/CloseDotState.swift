import CoreGraphics

public struct HoveredThumbnail: Equatable {
    public let windowID: Int
    public let frame: CGRect
    public init(windowID: Int, frame: CGRect) {
        self.windowID = windowID
        self.frame = frame
    }
}

public enum CloseDotAction: Equatable {
    case none
    case hide
    case show(center: CGPoint, windowID: Int)
}

/// Decides where the close dot is shown. It belongs to one window at a time and never travels:
/// entering another window hides the old dot, and the new window's own dot appears on the next tick.
public struct CloseDotState {
    private let missLimit: Int
    private var visible: HoveredThumbnail?
    private var misses = 0

    public init(missLimit: Int = 5) {
        self.missLimit = missLimit
    }

    /// `hovered` is the thumbnail under the cursor, or nil when the hit-test found none
    /// (which also happens while the cursor is on the dot's own panel).
    public mutating func update(cursor: CGPoint, hovered: HoveredThumbnail?) -> CloseDotAction {
        // Cursor on the visible dot: it keeps its owner, even over a neighbouring thumbnail.
        if let shown = visible, CloseDotPolicy.dotHitRect(thumbnail: shown.frame).contains(cursor) {
            misses = 0
            return .none
        }
        if let h = hovered, h.frame.contains(cursor) {
            misses = 0
            guard let shown = visible else {
                visible = h
                return .show(center: CloseDotPolicy.dotCenter(thumbnail: h.frame), windowID: h.windowID)
            }
            if shown.windowID == h.windowID { return .none }   // stays exactly where it was shown
            visible = nil                                       // other window: disappear first
            return .hide
        }
        guard let shown = visible else { return .none }
        if CloseDotPolicy.isOverThumbnailOrDot(cursor: cursor, thumbnail: shown.frame) {
            misses = 0
            return .none
        }
        misses += 1
        guard misses >= missLimit else { return .none }
        visible = nil
        misses = 0
        return .hide
    }

    /// Call when the feature is off or Mission Control closed.
    public mutating func reset() -> CloseDotAction {
        misses = 0
        guard visible != nil else { return .none }
        visible = nil
        return .hide
    }
}
