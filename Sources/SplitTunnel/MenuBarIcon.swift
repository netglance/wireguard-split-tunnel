import AppKit

/// Menu bar icon: a template shield, or a shield with a colored dot when something needs attention.
func menuBarImage(dot: NSColor?) -> NSImage {
    let name = "shield.lefthalf.filled"
    guard let dot else {
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Split Tunnel")!
        image.isTemplate = true
        return image
    }
    // Not a template image, so the dot keeps its color; the shield is drawn in labelColor,
    // which the drawing handler resolves for the menu bar's current appearance.
    let image = NSImage(size: NSSize(width: 19, height: 16), flipped: false) { _ in
        let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
            .withSymbolConfiguration(.init(paletteColors: [.labelColor]))!
        symbol.draw(in: NSRect(x: 0, y: 0, width: 16, height: 16))
        dot.setFill()
        NSBezierPath(ovalIn: NSRect(x: 12, y: 0, width: 7, height: 7)).fill()
        return true
    }
    image.isTemplate = false
    image.accessibilityDescription = "Split Tunnel"
    return image
}
