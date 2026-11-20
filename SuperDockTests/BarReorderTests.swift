import CoreGraphics
import Testing

// Compact (73), medium (152), compact (73) at an 85 pt bar.
private let reorder = BarReorder(lengths: [73, 152, 73], spacing: 6)

@Test func smallDragKeepsSlot() {
    #expect(reorder.target(from: 1, translation: 14) == 1)
    #expect(reorder.shift(of: 2, from: 1, target: 1) == 0)
    #expect(reorder.slotOffset(from: 1, target: 1) == 0)
}

@Test func wideTilePassesNarrowNeighbour() {
    // Trailing edge 79 + 60 + 152 = 291 is past the last tile's centre (237 + 36.5).
    #expect(reorder.target(from: 1, translation: 60) == 2)
    #expect(reorder.shift(of: 2, from: 1, target: 2) == -158)
    #expect(reorder.slotOffset(from: 1, target: 2) == 79)
}

@Test func narrowTileMovesBackToFront() {
    #expect(reorder.target(from: 2, translation: -237) == 0)
    #expect(reorder.shift(of: 0, from: 2, target: 0) == 79)
    #expect(reorder.shift(of: 1, from: 2, target: 0) == 79)
    #expect(reorder.slotOffset(from: 2, target: 0) == -237)
}

@Test func dragStaysWithinTiles() {
    #expect(reorder.clamp(500, from: 1) == 79)
    #expect(reorder.clamp(-500, from: 1) == -79)
}
