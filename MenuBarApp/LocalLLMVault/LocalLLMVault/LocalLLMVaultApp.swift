//
//  LocalLLMVaultApp.swift
//  LLM Vault - Menu Bar App
//

import SwiftUI
import ServiceManagement

@main
struct LocalLLMVaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateIcon()
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 420)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())

        print("✓ LLM Vault menu bar app started")

        if !UserDefaults.standard.bool(forKey: "hasCompletedSetup") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.firstLaunchSetup()
            }
        }
    }

    private func firstLaunchSetup() {
        // Install hooks if not already installed
        if !HookInstaller.shared.areHooksInstalled() {
            let alert = NSAlert()
            alert.messageText = "Welcome to LLM Vault"
            alert.informativeText = "LLM Vault protects your credentials when using Claude Code.\n\nThis will:\n• Install protection hooks into Claude Code\n• Enable launch at login\n\nYou can change these settings anytime from the menu bar."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Set Up")
            alert.addButton(withTitle: "Not Now")

            if alert.runModal() == .alertFirstButtonReturn {
                do {
                    try HookInstaller.shared.installHooks()
                    enableLaunchAtLogin()
                    UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                    updateIcon()
                } catch {
                    let errAlert = NSAlert()
                    errAlert.messageText = "Setup Failed"
                    errAlert.informativeText = "\(error.localizedDescription)\n\nYou can install manually by running install.sh from the project directory."
                    errAlert.alertStyle = .warning
                    errAlert.addButton(withTitle: "OK")
                    errAlert.runModal()
                }
            }
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
        }
    }

    private func enableLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            try? SMAppService.mainApp.register()
        }
    }

    func updateIcon() {
        let paused = VaultState.isPaused
        let iconName = paused ? "lock.open" : "lock.shield.fill"
        statusItem?.button?.image = NSImage(
            systemSymbolName: iconName,
            accessibilityDescription: paused ? "LLM Vault (Paused)" : "LLM Vault"
        )
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown ?? false {
                popover?.performClose(nil)
            } else {
                popover?.contentViewController = NSHostingController(rootView: MenuBarView())
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

// MARK: - Vault State (pause flag)

struct VaultState {
    private static let pausePath = "\(NSHomeDirectory())/.llm-vault/paused"

    static var isPaused: Bool {
        FileManager.default.fileExists(atPath: pausePath)
    }

    static func pause() {
        FileManager.default.createFile(atPath: pausePath, contents: nil)
    }

    static func resume() {
        try? FileManager.default.removeItem(atPath: pausePath)
    }

    static func toggle() {
        if isPaused { resume() } else { pause() }
    }
}
