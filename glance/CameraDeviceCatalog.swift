//
//  CameraDeviceCatalog.swift
//  glance
//
//  Resolves the app's camera preference (flat default, or split by built-in vs. external display) into the device to open.
//

import AVFoundation
import AppKit

struct CameraDevice: Identifiable, Hashable {
    let id: String // AVCaptureDevice.uniqueID
    let name: String
}

enum CameraDeviceCatalog {
    static func availableDevices() -> [CameraDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.map { CameraDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    /// True if the display glance targets is the Mac's built-in display
    /// (vs. an external monitor) — used to pick between the built-in/
    /// external camera overrides. Not `NSScreen.main`: that follows the
    /// key window, which is arbitrary at the lock screen.
    static func isUsingBuiltInDisplay() -> Bool {
        targetsBuiltInDisplay(
            pinnedID: GlanceSettings.shared.preferredDisplayID,
            screens: NSScreen.screens.compactMap { TargetDisplay($0) },
            main: NSScreen.main.flatMap { TargetDisplay($0) }
        )
    }

    /// The display-side facts `targetsBuiltInDisplay` needs, split from `NSScreen` so the choice is testable.
    struct TargetDisplay {
        let number: CGDirectDisplayID
        let uuid: String?
        let isBuiltIn: Bool

        init(number: CGDirectDisplayID, uuid: String?, isBuiltIn: Bool) {
            self.number = number
            self.uuid = uuid
            self.isBuiltIn = isBuiltIn
        }

        init?(_ screen: NSScreen) {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            else { return nil }
            let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue()
            self.init(
                number: number,
                uuid: uuid.flatMap { CFUUIDCreateString(nil, $0) as String? },
                isBuiltIn: CGDisplayIsBuiltin(number) != 0
            )
        }

        /// A saved display id is either a `CGDirectDisplayID` number (older installs) or a display UUID.
        func matches(displayID: String) -> Bool {
            displayID == String(number) || uuid?.caseInsensitiveCompare(displayID) == .orderedSame
        }
    }

    /// Decided here rather than via `NotchGeometry.preferredScreen()`, which consults the resolved camera and would
    /// recurse back into `resolvedDevice()`. A connected pin wins; a stale pin falls through. Unpinned, the overlay goes
    /// to the built-in panel whenever one is connected (a notched screen is always built-in), notched or not, and
    /// only then to `NSScreen.main`. Deliberately not "notch, else main": on a notchless laptop that is the key window's
    /// screen again.
    static func targetsBuiltInDisplay(pinnedID: String?, screens: [TargetDisplay], main: TargetDisplay?) -> Bool {
        if let pinnedID, let pinned = screens.first(where: { $0.matches(displayID: pinnedID) }) {
            return pinned.isBuiltIn
        }
        if screens.contains(where: { $0.isBuiltIn }) {
            return true
        }
        return main?.isBuiltIn ?? true
    }

    /// Display-specific override, then flat default, then the system default camera.
    static func resolvedDevice() -> AVCaptureDevice? {
        let settings = GlanceSettings.shared
        let preferredID = isUsingBuiltInDisplay()
            ? (settings.builtInDisplayCameraID ?? settings.defaultCameraID)
            : (settings.externalDisplayCameraID ?? settings.defaultCameraID)

        if let preferredID, let device = AVCaptureDevice(uniqueID: preferredID) {
            return device
        }
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
    }
}
