import AppKit

/// Maps an AX window element to its CGWindowID, the id CGWindowList and ScreenCaptureKit use.
/// Private, but stable for over a decade and used by AltTab, yabai and DockDoor; there's no public equivalent.
@_silgen_name("_AXUIElementGetWindow")
private func axUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Thin wrappers over the Accessibility C API.
enum AX {
    static func attribute(_ name: String, of element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    static func children(of element: AXUIElement) -> [AXUIElement] {
        attribute(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
    }

    static func role(of element: AXUIElement) -> String? {
        attribute(kAXRoleAttribute, of: element) as? String
    }

    static func subrole(of element: AXUIElement) -> String? {
        attribute(kAXSubroleAttribute, of: element) as? String
    }

    static func url(of element: AXUIElement) -> URL? {
        guard let raw = attribute(kAXURLAttribute, of: element), CFGetTypeID(raw) == CFURLGetTypeID() else { return nil }
        // The type-ID check makes this downcast safe; Swift can't conditionally cast to CF types.
        return unsafeDowncast(raw, to: CFURL.self) as URL
    }

    /// Frame in AX coordinates (top-left origin of the primary screen, y down).
    static func frame(of element: AXUIElement) -> CGRect? {
        guard let origin = value(kAXPositionAttribute, of: element, type: .cgPoint, initial: CGPoint.zero),
              let size = value(kAXSizeAttribute, of: element, type: .cgSize, initial: CGSize.zero) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        return axUIElementGetWindow(element, &id) == .success && id != 0 ? id : nil
    }

    static func set(_ name: String, of element: AXUIElement, to value: Bool) {
        AXUIElementSetAttributeValue(element, name as CFString, value ? kCFBooleanTrue : kCFBooleanFalse)
    }

    static func perform(_ action: String, on element: AXUIElement) {
        AXUIElementPerformAction(element, action as CFString)
    }

    /// The Dock's icon list. A new element each call, so it survives `killall Dock`.
    static func dockList() -> (pid: pid_t, list: AXUIElement)? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let pid = dock.processIdentifier
        guard let list = children(of: AXUIElementCreateApplication(pid)).first(where: { role(of: $0) == kAXListRole }) else { return nil }
        // A hung Dock would otherwise block the main thread for the 6 s system default.
        AXUIElementSetMessagingTimeout(list, 0.25)
        return (pid, list)
    }

    static var primaryScreenHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    private static func value<T: BitwiseCopyable>(_ name: String, of element: AXUIElement, type: AXValueType, initial: T) -> T? {
        guard let raw = attribute(name, of: element), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var result = initial
        // Same as above: the type-ID check is what makes this downcast safe.
        return AXValueGetValue(unsafeDowncast(raw, to: AXValue.self), type, &result) ? result : nil
    }
}
