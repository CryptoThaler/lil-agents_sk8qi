import SwiftUI
import AppKit
import Sparkle

@main
struct LilSk8ersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var controller: LilSk8ersController?
    var statusItem: NSStatusItem?
    var buildOverlayItem: NSMenuItem?
    var fullGameItem: NSMenuItem?
    let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        controller = LilSk8ersController()
        controller?.start()
        setupMenuBar()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.characters.forEach { $0.claudeSession?.terminate() }
    }

    // MARK: - Menu Bar

    func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "figure.walk", accessibilityDescription: "lil_sk8ers")
        }

        let menu = NSMenu()

        let char1Item = NSMenuItem(title: "AXO", action: #selector(toggleChar1), keyEquivalent: "1")
        char1Item.state = .on
        menu.addItem(char1Item)

        let char2Item = NSMenuItem(title: "Mudbug", action: #selector(toggleChar2), keyEquivalent: "2")
        char2Item.state = .on
        menu.addItem(char2Item)

        menu.addItem(NSMenuItem.separator())

        let buildOverlayItem = NSMenuItem(title: "Ramp Build Overlay", action: #selector(toggleBuildOverlay(_:)), keyEquivalent: "b")
        buildOverlayItem.target = self
        buildOverlayItem.state = controller?.buildOverlayEnabled == true ? .on : .off
        menu.addItem(buildOverlayItem)
        self.buildOverlayItem = buildOverlayItem

        let fullGameItem = NSMenuItem(title: "Full Game Mode", action: #selector(toggleFullGame(_:)), keyEquivalent: "g")
        fullGameItem.target = self
        fullGameItem.state = controller?.fullGameModeEnabled == true ? .on : .off
        menu.addItem(fullGameItem)
        self.fullGameItem = fullGameItem

        let resetRampsItem = NSMenuItem(title: "Reset Ramps", action: #selector(resetRamps), keyEquivalent: "r")
        resetRampsItem.target = self
        menu.addItem(resetRampsItem)

        let chatItem = NSMenuItem(title: "Chat", action: nil, keyEquivalent: "")
        let chatMenu = NSMenu()
        let axoChat = NSMenuItem(title: "Open AXO Chat", action: #selector(openAxoChat), keyEquivalent: "")
        axoChat.target = self
        chatMenu.addItem(axoChat)
        let mudbugChat = NSMenuItem(title: "Open Mudbug Chat", action: #selector(openMudbugChat), keyEquivalent: "")
        mudbugChat.target = self
        chatMenu.addItem(mudbugChat)
        chatItem.submenu = chatMenu
        menu.addItem(chatItem)

        menu.addItem(NSMenuItem.separator())

        let providerItem = NSMenuItem(title: "AI Provider", action: nil, keyEquivalent: "")
        let providerMenu = NSMenu()
        for provider in AgentProvider.allCases {
            let item = NSMenuItem(title: provider.menuTitle, action: #selector(switchProvider(_:)), keyEquivalent: "")
            item.representedObject = provider.rawValue
            item.state = provider == AgentProvider.current ? .on : .off
            providerMenu.addItem(item)
        }
        providerItem.submenu = providerMenu
        menu.addItem(providerItem)

        let soundItem = NSMenuItem(title: "Sounds", action: #selector(toggleSounds(_:)), keyEquivalent: "")
        soundItem.state = .on
        menu.addItem(soundItem)

        // Theme submenu
        let themeItem = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        let themeMenu = NSMenu()
        for (i, theme) in PopoverTheme.allThemes.enumerated() {
            let item = NSMenuItem(title: theme.name, action: #selector(switchTheme(_:)), keyEquivalent: "")
            item.tag = i
            item.state = i == 0 ? .on : .off
            themeMenu.addItem(item)
        }
        themeItem.submenu = themeMenu
        menu.addItem(themeItem)

        // Display submenu
        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        displayMenu.delegate = self
        let autoItem = NSMenuItem(title: "Auto (Main Display)", action: #selector(switchDisplay(_:)), keyEquivalent: "")
        autoItem.tag = -1
        autoItem.state = .on
        displayMenu.addItem(autoItem)
        displayMenu.addItem(NSMenuItem.separator())
        for (i, screen) in NSScreen.screens.enumerated() {
            let name = screen.localizedName
            let item = NSMenuItem(title: name, action: #selector(switchDisplay(_:)), keyEquivalent: "")
            item.tag = i
            item.state = .off
            displayMenu.addItem(item)
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        menu.addItem(NSMenuItem.separator())

        let updateItem = NSMenuItem(title: "Check for Updates…", action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
        updateItem.target = updaterController
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - Menu Actions

    @objc func switchTheme(_ sender: NSMenuItem) {
        let idx = sender.tag
        guard idx < PopoverTheme.allThemes.count else { return }
        PopoverTheme.current = PopoverTheme.allThemes[idx]

        if let themeMenu = sender.menu {
            for item in themeMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }

        controller?.characters.forEach { char in
            let wasOpen = char.isIdleForPopover
            if wasOpen { char.popoverWindow?.orderOut(nil) }
            char.popoverWindow = nil
            char.terminalView = nil
            char.thinkingBubbleWindow = nil
            if wasOpen {
                char.createPopoverWindow()
                if let session = char.claudeSession, !session.history.isEmpty {
                    char.terminalView?.replayHistory(session.history)
                }
                char.updatePopoverPosition()
                char.popoverWindow?.orderFrontRegardless()
                char.popoverWindow?.makeKey()
                if let terminal = char.terminalView {
                    char.popoverWindow?.makeFirstResponder(terminal.inputField)
                }
            }
        }
    }

    @objc func switchDisplay(_ sender: NSMenuItem) {
        let idx = sender.tag
        controller?.pinnedScreenIndex = idx

        if let displayMenu = sender.menu {
            for item in displayMenu.items {
                item.state = item.tag == idx ? .on : .off
            }
        }
    }

    @objc func switchProvider(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let provider = AgentProvider(rawValue: raw) else { return }

        AgentProvider.setCurrent(provider)

        if let providerMenu = sender.menu {
            for item in providerMenu.items {
                let isSelected = (item.representedObject as? String) == provider.rawValue
                item.state = isSelected ? .on : .off
            }
        }

        controller?.characters.forEach { $0.resetSessionForProviderChange() }
    }

    @objc func toggleBuildOverlay(_ sender: NSMenuItem) {
        let enabled = sender.state != .on
        controller?.setBuildOverlayEnabled(enabled)
        sender.state = enabled ? .on : .off
    }

    @objc func toggleFullGame(_ sender: NSMenuItem) {
        let enabled = sender.state != .on
        controller?.setFullGameMode(enabled)
        sender.state = enabled ? .on : .off
    }

    @objc func resetRamps() {
        controller?.resetRamps()
    }

    @objc func openAxoChat() {
        controller?.openChat(for: .axo)
        fullGameItem?.state = .off
    }

    @objc func openMudbugChat() {
        controller?.openChat(for: .mudbug)
        fullGameItem?.state = .off
    }

    @objc func toggleChar1(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 0 else { return }
        let char = chars[0]
        if char.window.isVisible {
            char.window.orderOut(nil)
            char.queuePlayer.pause()
            sender.state = .off
        } else {
            char.window.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func toggleChar2(_ sender: NSMenuItem) {
        guard let chars = controller?.characters, chars.count > 1 else { return }
        let char = chars[1]
        if char.window.isVisible {
            char.window.orderOut(nil)
            char.queuePlayer.pause()
            sender.state = .off
        } else {
            char.window.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func toggleDebug(_ sender: NSMenuItem) {
        guard let debugWin = controller?.debugWindow else { return }
        if debugWin.isVisible {
            debugWin.orderOut(nil)
            sender.state = .off
        } else {
            debugWin.orderFrontRegardless()
            sender.state = .on
        }
    }

    @objc func toggleSounds(_ sender: NSMenuItem) {
        WalkerCharacter.soundsEnabled.toggle()
        sender.state = WalkerCharacter.soundsEnabled ? .on : .off
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {}
