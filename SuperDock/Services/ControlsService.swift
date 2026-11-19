import AudioToolbox   // kAudioHardwareServiceDeviceProperty_VirtualMainVolume
import CoreAudio
import CoreGraphics
import CoreWLAN
import Foundation
import Observation
import os

private let log = Logger(subsystem: "dev.superdock.SuperDock", category: "controls")

/// Output volume and mute for the default output device, via CoreAudio.
@MainActor @Observable
final class AudioService {
    static let shared = AudioService()

    private(set) var volume: Float = 0     // 0...1
    private(set) var isMuted = false
    /// false when the output (e.g. some HDMI displays) has no software volume.
    private(set) var hasVolume = false

    @ObservationIgnored private var listenedDevices: Set<AudioObjectID> = []

    private init() {
        refresh()
        // Output-device switches (headphones, AirPods) come from the system object…
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice, scope: kAudioObjectPropertyScopeGlobal)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, .main) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        guard let device = Self.outputDevice() else { return }
        // …and volume keys change the device itself. Listeners on devices no longer in use just trigger a harmless re-read.
        if listenedDevices.insert(device).inserted {
            for selector in [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute] {
                var address = Self.address(selector)
                AudioObjectAddPropertyListenerBlock(device, &address, .main) { [weak self] _, _ in
                    MainActor.assumeIsolated { self?.refresh() }
                }
            }
        }
        var level: Float32 = 0
        var mute: UInt32 = 0
        hasVolume = Self.get(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, &level)
        volume = level
        isMuted = Self.get(device, kAudioDevicePropertyMute, &mute) && mute != 0
    }

    func setVolume(_ value: Float) {
        guard let device = Self.outputDevice() else { return }
        var level = min(max(value, 0), 1)
        Self.set(device, kAudioHardwareServiceDeviceProperty_VirtualMainVolume, &level)
        volume = level
    }

    func toggleMute() {
        guard let device = Self.outputDevice() else { return }
        var mute: UInt32 = isMuted ? 0 : 1
        Self.set(device, kAudioDevicePropertyMute, &mute)
        isMuted.toggle()
    }

    private static func outputDevice() -> AudioObjectID? {
        var device = AudioObjectID(0)
        guard get(AudioObjectID(kAudioObjectSystemObject), kAudioHardwarePropertyDefaultOutputDevice, &device,
                  scope: kAudioObjectPropertyScopeGlobal), device != 0 else { return nil }
        return device
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func get<T: BitwiseCopyable>(
        _ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T,
        scope: AudioObjectPropertyScope = kAudioDevicePropertyScopeOutput
    ) -> Bool {
        var address = address(selector, scope: scope)
        guard AudioObjectHasProperty(object, &address) else { return false }
        var size = UInt32(MemoryLayout<T>.size)
        return AudioObjectGetPropertyData(object, &address, 0, nil, &size, &value) == noErr
    }

    private static func set<T: BitwiseCopyable>(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector, _ value: inout T) {
        var address = address(selector)
        let status = AudioObjectSetPropertyData(object, &address, 0, nil, UInt32(MemoryLayout<T>.size), &value)
        if status != noErr { log.error("CoreAudio set \(selector) failed: \(status)") }
    }
}

/// Wi-Fi power via CoreWLAN. (Reading the network name needs Location access, so only on/off is shown.)
@MainActor
enum WiFiControl {
    static var isOn: Bool? { CWWiFiClient.shared().interface()?.powerOn() }

    static func setPower(_ enabled: Bool) {
        do {
            try CWWiFiClient.shared().interface()?.setPower(enabled)
        } catch {
            log.error("Wi-Fi power change failed: \(error)")
        }
    }
}

/// Built-in display brightness via the private DisplayServices framework (no public API exists).
/// Looked up at runtime, so if Apple removes it the brightness control just disappears.
@MainActor
enum BrightnessControl {
    private typealias Getter = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias Setter = @convention(c) (UInt32, Float) -> Int32

    private static let framework = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY)
    private static let getter = dlsym(framework, "DisplayServicesGetBrightness").map { unsafeBitCast($0, to: Getter.self) }
    private static let setter = dlsym(framework, "DisplayServicesSetBrightness").map { unsafeBitCast($0, to: Setter.self) }

    /// nil when the main display's brightness isn't software-controllable (most external displays).
    static var brightness: Float? {
        var value: Float = 0
        guard let getter, getter(CGMainDisplayID(), &value) == 0 else { return nil }
        return value
    }

    static func set(_ value: Float) {
        _ = setter?(CGMainDisplayID(), min(max(value, 0), 1))
    }
}
