import AppKit

// Private CoreGraphics/SkyLight calls. There's no public API for a window that stays perfectly still while
// Spaces slide: `.canJoinAllSpaces` puts a *copy* of the window on every Space, and those copies slide with the
// Space transition (two bars visible mid-swipe). The Dock avoids this by living in its own window-server space;
// this does the same. NotchDrop and other notch apps rely on the same calls.
private typealias ConnectionID = UInt32
private typealias SpaceID = UInt64

@_silgen_name("_CGSDefaultConnection")
private func cgsDefaultConnection() -> ConnectionID
@_silgen_name("CGSSpaceCreate")
private func cgsSpaceCreate(_ connection: ConnectionID, _ flags: Int32, _ options: NSDictionary?) -> SpaceID
@_silgen_name("CGSSpaceSetAbsoluteLevel")
private func cgsSpaceSetAbsoluteLevel(_ connection: ConnectionID, _ space: SpaceID, _ level: Int32)
@_silgen_name("CGSShowSpaces")
private func cgsShowSpaces(_ connection: ConnectionID, _ spaces: NSArray)
@_silgen_name("CGSAddWindowsToSpaces")
private func cgsAddWindowsToSpaces(_ connection: ConnectionID, _ windows: NSArray, _ spaces: NSArray)

/// One window-server space that sits above every user Space, so windows in it are shown once and never move
/// when the user swipes between Spaces or switches apps — exactly like the Dock.
@MainActor
enum StickySpace {
    private static let connection = cgsDefaultConnection()

    private static let space: SpaceID = {
        let space = cgsSpaceCreate(connection, 1, nil)
        // Above normal Spaces; the bar still hides over full-screen apps because it follows the (hidden) Dock there.
        cgsSpaceSetAbsoluteLevel(connection, space, 100)
        cgsShowSpaces(connection, [space] as NSArray)
        return space
    }()

    static func add(_ window: NSWindow) {
        cgsAddWindowsToSpaces(connection, [window.windowNumber] as NSArray, [space] as NSArray)
    }
}
