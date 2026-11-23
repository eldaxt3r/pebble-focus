import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = FocusSessionStore()
    private let permissions = PermissionsManager()
    private let updateChecker = UpdateChecker()

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    private var dynamicIslandController: DynamicIslandPanelController!
    private var stickyNoteController: StickyNotePanelController!
    private var approvalPanelController: AppApprovalPanelController!
    private var recapPanelController: SessionRecapPanelController!
    private var setupWindowController: SessionSetupWindowController!

    private var appWatcher: AppWatcher!
    private var browserTabWatcher: BrowserTabWatcher!

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Regular app: Pebble shows in the Dock with the running dot; clicking it opens the menu.
        NSApp.setActivationPolicy(.regular)
        setupMainMenu()

        setupStatusItem()
        setupPopover()
        setupPanels()
        setupWatchers()

        // Show floating transparent Pebble Dynamic Island immediately
        dynamicIslandController.show()

        // Look for a newer Pebble on the website (launch + every few hours)
        updateChecker.start()

        // Opened by hand (Finder, Launchpad, Dock)? Show the menu so it's obvious Pebble is running.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.showPopover()
        }

        // Re-center Dynamic Island if display configuration changes
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.dynamicIslandController.reposition()
            }
        }
    }

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu(title: "Pebble")
        appMenu.addItem(withTitle: "About Pebble", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesFromMenu), keyEquivalent: "")
        updates.target = self
        appMenu.addItem(updates)
        let open = NSMenuItem(title: "Open Pebble Menu", action: #selector(openMenuFromMenu), keyEquivalent: "p")
        open.target = self
        appMenu.addItem(open)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Pebble", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Pebble", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    @objc private func checkForUpdatesFromMenu() {
        Task { await updateChecker.check(userInitiated: true) }
    }

    @objc private func openMenuFromMenu() {
        showPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.toolTip = "Pebble Focus Companion"
        }
        updateStatusBarIcon()
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)

        let hostingController = NSHostingController(
            rootView: MenuBarPopoverView(
                store: store,
                permissions: permissions,
                updateChecker: updateChecker,
                onOpenSetup: { [weak self] in
                    self?.popover.performClose(nil)
                    self?.setupWindowController.show()
                },
                onQuitApp: {
                    NSApp.terminate(nil)
                }
            )
        )
        hostingController.sizingOptions = .preferredContentSize
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: 344, height: 295)
    }

    private func setupPanels() {
        dynamicIslandController = DynamicIslandPanelController(store: store) { [weak self] in
            self?.togglePopover()
        }
        stickyNoteController = StickyNotePanelController(store: store)
        approvalPanelController = AppApprovalPanelController(store: store)
        recapPanelController = SessionRecapPanelController(store: store)
        setupWindowController = SessionSetupWindowController(store: store, permissions: permissions)

        store.onStatusIconNeedsUpdate = { [weak self] in
            self?.updateStatusBarIcon()
        }
        store.onDynamicIslandNeedsLayout = { [weak self] in
            self?.dynamicIslandController.reposition()
        }
        store.onApprovalPanelVisibilityChanged = { [weak self] visible in
            self?.approvalPanelController.setVisible(visible)
        }
        store.onStickyNoteVisibilityChanged = { [weak self] visible in
            self?.stickyNoteController.setVisible(visible)
        }
        store.onRecapVisibilityChanged = { [weak self] visible in
            self?.recapPanelController.setVisible(visible)
        }
    }

    private func setupWatchers() {
        appWatcher = AppWatcher(store: store)
        appWatcher.start()

        browserTabWatcher = BrowserTabWatcher(store: store)
        browserTabWatcher.start()
    }

    /// Clicking Pebble's icon again (Finder, Dock, Launchpad) opens the same menu as the menu bar icon.
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPopover()
        return false
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        permissions.refresh()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            permissions.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .maxY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Renders miniature Pebble + live status dot (dark = idle, green = focused, red = distracted) for the macOS menu bar.
    private func updateStatusBarIcon() {
        guard let button = statusItem.button else { return }

        let size = NSSize(width: 22, height: 20)
        let image = NSImage(size: size, flipped: true) { rect in
            let s = min(rect.width, rect.height) / 100.0
            let ox: CGFloat = 0
            let oy: CGFloat = 0

            func pt(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
                NSPoint(x: ox + x * s, y: oy + y * s)
            }

            let bodyPath = NSBezierPath()
            bodyPath.move(to: pt(50, 19))
            bodyPath.curve(to: pt(81.5, 47), controlPoint1: pt(67, 19), controlPoint2: pt(81, 31))
            bodyPath.curve(to: pt(62, 82), controlPoint1: pt(82, 63), controlPoint2: pt(75.5, 77))
            bodyPath.curve(to: pt(24.5, 75), controlPoint1: pt(49, 86.5), controlPoint2: pt(33, 84))
            bodyPath.curve(to: pt(18, 43), controlPoint1: pt(16.5, 66.5), controlPoint2: pt(16.5, 53))
            bodyPath.curve(to: pt(50, 19), controlPoint1: pt(20, 29), controlPoint2: pt(33, 19))
            bodyPath.close()

            self.store.faceState.bodyNSColor.setFill()
            bodyPath.fill()

            // Eyes (#F6F1E7)
            NSColor(red: 246/255, green: 241/255, blue: 231/255, alpha: 1).setFill()
            let leftEye = NSBezierPath(ovalIn: NSRect(x: 35.8 * s, y: 39.6 * s, width: 12.4 * s, height: 14.8 * s))
            let rightEye = NSBezierPath(ovalIn: NSRect(x: 53.8 * s, y: 39.6 * s, width: 12.4 * s, height: 14.8 * s))
            leftEye.fill()
            rightEye.fill()

            // Live Status Dot (bottom-right)
            let dotColor: NSColor
            if self.store.faceState == .mad {
                dotColor = NSColor(red: 210/255, green: 69/255, blue: 60/255, alpha: 1)
            } else if self.store.sessionActive {
                dotColor = NSColor(red: 53/255, green: 164/255, blue: 92/255, alpha: 1)
            } else {
                dotColor = NSColor.darkGray
            }

            let dotRect = NSRect(x: rect.width - 7.5, y: rect.height - 7.5, width: 6.5, height: 6.5)
            NSColor.white.setFill()
            NSBezierPath(ovalIn: dotRect.insetBy(dx: -1, dy: -1)).fill()
            dotColor.setFill()
            NSBezierPath(ovalIn: dotRect).fill()

            return true
        }

        image.isTemplate = false
        button.image = image
    }
}
