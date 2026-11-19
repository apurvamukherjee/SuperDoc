import CoreGraphics
import Testing

// Numbers from a real 1710×1107 MacBook screen with a bottom Dock (tilesize 65).
private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1107)
private let visible = CGRect(x: 0, y: 0, width: 1710, height: 1073)
private let bottomDock = CGRect(x: 314, y: 0, width: 1082, height: 85)

@Test func flipsAXToAppKit() {
    let axRect = CGRect(x: 314, y: 1022, width: 1082, height: 85)
    #expect(BarPlacement.appKitRect(fromAX: axRect, primaryScreenHeight: 1107) == bottomDock)
}

@Test func autoHiddenDockIsNotShowing() {
    // Auto-hide parks the Dock at AX y = screen height, i.e. just below the screen.
    let hidden = BarPlacement.appKitRect(fromAX: CGRect(x: 314, y: 1107, width: 1082, height: 85), primaryScreenHeight: 1107)
    #expect(!BarPlacement.isShowing(hidden, on: screen))
    #expect(BarPlacement.isShowing(bottomDock, on: screen))
    // Mid-slide still counts as showing, so the bar slides along with it.
    #expect(BarPlacement.isShowing(bottomDock.offsetBy(dx: 0, dy: -60), on: screen))
}

@Test func dockOnSecondScreen() {
    let external = CGRect(x: 1710, y: 0, width: 2560, height: 1440)
    let dock = CGRect(x: 2500, y: 0, width: 900, height: 85)
    #expect(!BarPlacement.isShowing(dock, on: screen))
    #expect(BarPlacement.isShowing(dock, on: external))
}

@Test func orientationFromGeometry() {
    #expect(BarPlacement.orientation(of: bottomDock, in: visible) == .bottom)
    #expect(BarPlacement.orientation(of: CGRect(x: 0, y: 200, width: 85, height: 700), in: visible) == .left)
    #expect(BarPlacement.orientation(of: CGRect(x: 1625, y: 200, width: 85, height: 700), in: visible) == .right)
}

@Test(arguments: [
    (BarPosition.trailing, CGRect(x: 1404, y: 0, width: 240, height: 85)),
    (BarPosition.leading, CGRect(x: 66, y: 0, width: 240, height: 85)),
    (BarPosition.outside, CGRect(x: 735, y: 93, width: 240, height: 85))
])
func bottomDockPositions(position: BarPosition, expected: CGRect) {
    #expect(BarPlacement.barFrame(dock: bottomDock, bounds: visible, position: position, gap: 8, length: 240) == expected)
}

@Test func ridesTheAutoHideSlide() {
    let sliding = bottomDock.offsetBy(dx: 0, dy: -40)
    #expect(BarPlacement.barFrame(dock: sliding, bounds: visible, position: .trailing, gap: 8, length: 240).minY == -40)
}

@Test func wideDockFallsBackToAbove() {
    let wideDock = CGRect(x: 100, y: 0, width: 1500, height: 85)
    #expect(BarPlacement.barFrame(dock: wideDock, bounds: visible, position: .trailing, gap: 8, length: 240)
            == CGRect(x: 730, y: 93, width: 240, height: 85))
}

@Test func sideDocks() {
    let left = CGRect(x: 0, y: 300, width: 85, height: 400)
    let right = CGRect(x: 1625, y: 300, width: 85, height: 400)
    #expect(BarPlacement.barFrame(dock: left, bounds: visible, position: .outside, gap: 8, length: 240)
            == CGRect(x: 93, y: 380, width: 85, height: 240))
    #expect(BarPlacement.barFrame(dock: right, bounds: visible, position: .outside, gap: 8, length: 240)
            == CGRect(x: 1532, y: 380, width: 85, height: 240))
    #expect(BarPlacement.barFrame(dock: left, bounds: visible, position: .leading, gap: 8, length: 240)
            == CGRect(x: 0, y: 708, width: 85, height: 240))
    #expect(BarPlacement.barFrame(dock: left, bounds: visible, position: .trailing, gap: 8, length: 240)
            == CGRect(x: 0, y: 52, width: 85, height: 240))
}

@Test func tallSideDockFallsBackToBeside() {
    // Real macOS 26 left Dock: AX (10, 82, 78×977) → only 48 pt free below it.
    let tall = CGRect(x: 10, y: 48, width: 78, height: 977)
    #expect(BarPlacement.barFrame(dock: tall, bounds: visible, position: .trailing, gap: 8, length: 240)
            == CGRect(x: 96, y: 416.5, width: 78, height: 240))
}
