import Foundation

/// Keeps realtime spectrum work separate from the otherwise static EQ editor.
/// The active EQ window retains display-rate spectrum motion; background windows
/// do not own a TimelineView and therefore produce no periodic UI frames.
enum EQCanvasRenderPolicy {
    static let spectrumFrameInterval: TimeInterval = 1.0 / 60.0

    static func shouldAnimate(
        windowForeground: Bool,
        engineRunning: Bool,
        preEqEnabled: Bool,
        postEqEnabled: Bool,
        bypassed: Bool
    ) -> Bool {
        guard windowForeground, engineRunning else { return false }
        return preEqEnabled || (postEqEnabled && !bypassed)
    }
}
