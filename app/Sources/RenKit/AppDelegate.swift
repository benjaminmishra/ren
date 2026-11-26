import SwiftUI
import AppKit

// MARK: - Native macOS Menu Bar Widget
public class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    public var onRescan: (() -> Void)?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = Self.makeMenuBarIcon()
            button.image?.accessibilityDescription = "Ren"
        }
        setupMenu()
    }

    /// Minimal Swedish geometric mark (open Nordic ring + centered pure drop) as a crisp template icon.
    private static func makeMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            let center = NSPoint(x: 9, y: 9)
            let radius: CGFloat = 6.2

            NSColor.labelColor.setStroke()
            let arc = NSBezierPath()
            arc.lineWidth = 1.85
            arc.lineCapStyle = .round
            // Open arc leaving a crisp Nordic gap in the upper-right
            arc.appendArc(withCenter: center, radius: radius, startAngle: 86, endAngle: 35, clockwise: false)
            arc.stroke()

            // Centered pure droplet/dot echoing the app icon
            NSColor.labelColor.setFill()
            let drop = NSBezierPath()
            drop.move(to: NSPoint(x: 9, y: 11.7))
            drop.curve(to: NSPoint(x: 11.1, y: 8.2), controlPoint1: NSPoint(x: 9.8, y: 10.4), controlPoint2: NSPoint(x: 11.1, y: 9.4))
            drop.curve(to: NSPoint(x: 9, y: 6.3), controlPoint1: NSPoint(x: 11.1, y: 7.1), controlPoint2: NSPoint(x: 10.2, y: 6.3))
            drop.curve(to: NSPoint(x: 6.9, y: 8.2), controlPoint1: NSPoint(x: 7.8, y: 6.3), controlPoint2: NSPoint(x: 6.9, y: 7.1))
            drop.curve(to: NSPoint(x: 9, y: 11.7), controlPoint1: NSPoint(x: 6.9, y: 9.4), controlPoint2: NSPoint(x: 8.2, y: 10.4))
            drop.close()
            drop.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    func setupMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "Ren", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "Ren",
            attributes: [.font: NSFont.boldSystemFont(ofSize: 13)]
        )
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Open Dashboard", action: #selector(openApp), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Rescan Storage", action: #selector(triggerScan), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Ren", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc public func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc public func triggerScan() {
        openApp()
        onRescan?()
    }

    @objc public func quitApp() {
        NSApp.terminate(nil)
    }

    public func applicationWillTerminate(_ notification: Notification) {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }
}
