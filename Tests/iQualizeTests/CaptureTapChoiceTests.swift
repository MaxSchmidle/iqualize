import CoreAudio
import XCTest
import IQCaptureProtocol
@testable import iQualize

/// The global stereo tap always reports 48 kHz, so on a 44.1 kHz device every
/// sample was converted twice. These pin when the capture path taps the output
/// device directly instead, and that the app and the helper agree on how the
/// device is named across the process boundary.
final class CaptureTapChoiceTests: XCTestCase {

    // MARK: - Helper-side rule

    func testPrefersDeviceTapForStereoDeviceAtAnotherRate() {
        XCTAssertTrue(CaptureTapChoice.prefersDeviceTap(
            globalSampleRate: 48_000, deviceSampleRate: 44_100, deviceChannels: 2))
        XCTAssertTrue(CaptureTapChoice.prefersDeviceTap(
            globalSampleRate: 48_000, deviceSampleRate: 96_000, deviceChannels: 2))
    }

    func testKeepsGlobalTapWhenRatesAlreadyMatch() {
        XCTAssertFalse(CaptureTapChoice.prefersDeviceTap(
            globalSampleRate: 48_000, deviceSampleRate: 48_000, deviceChannels: 2))
    }

    func testKeepsGlobalTapForNonStereoDeviceStreams() {
        XCTAssertFalse(CaptureTapChoice.prefersDeviceTap(
            globalSampleRate: 48_000, deviceSampleRate: 44_100, deviceChannels: 1))
        XCTAssertFalse(CaptureTapChoice.prefersDeviceTap(
            globalSampleRate: 48_000, deviceSampleRate: 44_100, deviceChannels: 6))
    }

    func testDeviceUIDArgumentParsing() {
        XCTAssertEqual(CaptureTapChoice.deviceUID(fromArguments: ["helper", "--device-uid", "dac"]), "dac")
        XCTAssertNil(CaptureTapChoice.deviceUID(fromArguments: ["helper"]))
        XCTAssertNil(CaptureTapChoice.deviceUID(fromArguments: ["helper", "--device-uid"]))
        XCTAssertNil(CaptureTapChoice.deviceUID(fromArguments: ["helper", "--device-uid", ""]))
    }

    // MARK: - App-side eligibility

    private func device(channels: UInt32?, transport: UInt32?, uid: String? = "uid") -> CoreAudioOutputDevice {
        CoreAudioOutputDevice(id: 1, name: "Device", uid: uid, nominalSampleRate: 44_100,
                              outputChannelCount: channels, transportType: transport)
    }

    func testWiredStereoDevicesAreOfferedForADeviceTap() {
        for transport in [kAudioDeviceTransportTypeBuiltIn, kAudioDeviceTransportTypeUSB,
                          kAudioDeviceTransportTypeFireWire, kAudioDeviceTransportTypeThunderbolt,
                          kAudioDeviceTransportTypePCI] {
            XCTAssertEqual(device(channels: 2, transport: transport).deviceTapUID, "uid")
        }
    }

    func testBluetoothAirPlayVirtualAndAggregateDevicesKeepTheGlobalTap() {
        for transport in [kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE,
                          kAudioDeviceTransportTypeAirPlay, kAudioDeviceTransportTypeVirtual,
                          kAudioDeviceTransportTypeAggregate] {
            XCTAssertNil(device(channels: 2, transport: transport).deviceTapUID)
        }
    }

    func testMultiChannelAndUnknownDevicesKeepTheGlobalTap() {
        XCTAssertNil(device(channels: 6, transport: kAudioDeviceTransportTypeUSB).deviceTapUID)
        XCTAssertNil(device(channels: nil, transport: kAudioDeviceTransportTypeUSB).deviceTapUID)
        XCTAssertNil(device(channels: 2, transport: nil).deviceTapUID)
        XCTAssertNil(device(channels: 2, transport: kAudioDeviceTransportTypeUSB, uid: nil).deviceTapUID)
    }

    // MARK: - Across the process boundary

    /// Starts CaptureClient against a stand-in helper that records its argv and
    /// never handshakes, and returns the device UID the helper would parse.
    private func uidSeenByHelper(offering deviceUID: String?) throws -> String? {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("iqualize-tapchoice-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let argsFile = dir.appendingPathComponent("args")
        let helper = dir.appendingPathComponent("helper.sh")
        try "#!/bin/sh\nprintf '%s\\n' \"$@\" > '\(argsFile.path)'\nsleep 30\n"
            .write(to: helper, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)

        let client = CaptureClient(handshakeTimeoutNanoseconds: 300_000_000)
        XCTAssertThrowsError(try client.start(helperURL: helper, deviceUID: deviceUID))
        let recorded = (try? String(contentsOf: argsFile, encoding: .utf8)) ?? ""
        let arguments = recorded.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        return CaptureTapChoice.deviceUID(fromArguments: [helper.path] + arguments)
    }

    func testClientHandsTheOfferedDeviceToTheHelper() throws {
        XCTAssertEqual(try uidSeenByHelper(offering: "BuiltInHeadphoneOutputDevice"),
                       "BuiltInHeadphoneOutputDevice")
    }

    func testClientOffersNoDeviceWhenNoneIsEligible() throws {
        XCTAssertNil(try uidSeenByHelper(offering: nil))
    }
}
