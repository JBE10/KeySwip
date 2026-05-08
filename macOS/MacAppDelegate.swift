import AppKit
import SwiftUI

@main
struct KeySwipMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    private var multipeerManager: MultipeerManager!
    private var menuBarManager: MenuBarManager!
    private let commandRouter = CommandRouter()

    func applicationDidFinishLaunching(_ notification: Notification) {
        enforceSingleInstance()

        NSApp.setActivationPolicy(.accessory)

        multipeerManager = MultipeerManager(role: .hostAdvertiser)
        setupInvitationHandling()
        
        multipeerManager.didReceiveData = { [weak self] data, peerID in
            self?.commandRouter.handle(data: data, from: peerID)
        }
        
        menuBarManager = MenuBarManager(multipeerManager: multipeerManager)
        menuBarManager.setupMenuBar()

        KeyInjector.requestPermission()
        multipeerManager.start()
    }

    private func setupInvitationHandling() {
        multipeerManager.invitationHandler = { [weak self] peerID, completion in
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Solicitud de conexión"
                alert.informativeText = "¿Deseas permitir que '\(peerID.displayName)' controle este Mac?"
                alert.addButton(withTitle: "Permitir")
                alert.addButton(withTitle: "Rechazar")
                alert.alertStyle = .informational
                
                // Forzamos que la alerta aparezca encima de todo
                NSApp.activate(ignoringOtherApps: true)
                
                let response = alert.runModal()
                completion(response == .alertFirstButtonReturn)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        multipeerManager?.stop()
    }

    private func enforceSingleInstance() {
        guard let bundleId = Bundle.main.bundleIdentifier else { return }
        let mine = NSRunningApplication.current.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId)
            .contains { $0.processIdentifier != mine }
        if others {
            NSApp.terminate(nil)
        }
    }
}
