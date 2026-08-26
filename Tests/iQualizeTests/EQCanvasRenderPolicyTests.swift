import XCTest
@testable import iQualize

final class EQCanvasRenderPolicyTests: XCTestCase {
    func testAnimationRequiresVisibleRunningWindowAndActiveTrace() {
        XCTAssertFalse(EQCanvasRenderPolicy.shouldAnimate(
            windowForeground: false,
            engineRunning: true,
            preEqEnabled: true,
            postEqEnabled: true,
            bypassed: false
        ))
        XCTAssertFalse(EQCanvasRenderPolicy.shouldAnimate(
            windowForeground: true,
            engineRunning: false,
            preEqEnabled: true,
            postEqEnabled: true,
            bypassed: false
        ))
        XCTAssertFalse(EQCanvasRenderPolicy.shouldAnimate(
            windowForeground: true,
            engineRunning: true,
            preEqEnabled: false,
            postEqEnabled: false,
            bypassed: false
        ))
    }

    func testPreEqRemainsAnimatedWhileBypassed() {
        XCTAssertTrue(EQCanvasRenderPolicy.shouldAnimate(
            windowForeground: true,
            engineRunning: true,
            preEqEnabled: true,
            postEqEnabled: false,
            bypassed: true
        ))
    }

    func testPostEqStopsAnimatingWhileBypassed() {
        XCTAssertFalse(EQCanvasRenderPolicy.shouldAnimate(
            windowForeground: true,
            engineRunning: true,
            preEqEnabled: false,
            postEqEnabled: true,
            bypassed: true
        ))
        XCTAssertTrue(EQCanvasRenderPolicy.shouldAnimate(
            windowForeground: true,
            engineRunning: true,
            preEqEnabled: false,
            postEqEnabled: true,
            bypassed: false
        ))
    }

    func testForegroundSpectrumRateIsSixtyFramesPerSecond() {
        XCTAssertEqual(EQCanvasRenderPolicy.spectrumFrameInterval, 1.0 / 60.0, accuracy: 0.000_001)
    }
}
