//
//  LocalLLMVaultApp.swift
//  LLM Vault - Menu Bar App
//

import SwiftUI

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
    var ipcServer: IPCServer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "lock.shield.fill", accessibilityDescription: "LLM Vault")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover?.contentSize = NSSize(width: 300, height: 400)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MenuBarView())

        ipcServer = IPCServer()
        ipcServer?.delegate = self
        ipcServer?.start()

        print("✓ LLM Vault menu bar app started")
    }

    @objc func togglePopover() {
        if let button = statusItem?.button {
            if popover?.isShown ?? false {
                popover?.performClose(nil)
            } else {
                popover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }
}

extension AppDelegate: IPCServerDelegate {
    func credentialRequested(keyName: String, context: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            let dialog = CredentialInputDialog(keyName: keyName, context: context, completion: completion)
            dialog.show()
        }
    }
}
