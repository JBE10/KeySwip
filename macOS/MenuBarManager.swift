import AppKit
import Combine

/// Barra de menú: ítem en `NSStatusBar` + menú con estado Multipeer y salida.
final class MenuBarManager: NSObject {
    private let multipeer: MultipeerManager
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(multipeerManager: MultipeerManager) {
        self.multipeer = multipeerManager
        super.init()
    }

    func setupMenuBar() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        guard let button = item.button else { return }
        button.image = Self.makeStatusImage()
        button.image?.isTemplate = true
        button.toolTip = "KeySwip"

        item.menu = buildMenu()

        multipeer.$connectedPeers
            .receive(on: RunLoop.main)
            .sink { [weak self] peers in
                self?.statusItem?.menu = self?.buildMenu()
                self?.updateButtonIcon(connected: !peers.isEmpty)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.statusItem?.menu = self?.buildMenu()
                if let peers = self?.multipeer.connectedPeers {
                    self?.updateButtonIcon(connected: !peers.isEmpty)
                }
            }
            .store(in: &cancellables)
    }

    func refreshFromSystemState() {
        statusItem?.menu = buildMenu()
        updateButtonIcon(connected: !multipeer.connectedPeers.isEmpty)
    }

    private func updateButtonIcon(connected: Bool) {
        guard let button = statusItem?.button else { return }
        button.image = Self.makeStatusImage()
        button.image?.isTemplate = true
        if connected {
            button.contentTintColor = .systemGreen
        } else {
            button.contentTintColor = .systemOrange
        }
    }

    private static func makeStatusImage() -> NSImage {
        let sym =
            NSImage(systemSymbolName: "keyboard", accessibilityDescription: "KeySwip")
            ?? NSImage(systemSymbolName: "character.textbox", accessibilityDescription: "KeySwip")
            ?? NSImage()
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        return sym.withSymbolConfiguration(config) ?? sym
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        if !KeyInjector.hasPermission() {
            let warn = NSMenuItem(
                title: "Se requiere Accesibilidad para inyectar teclas",
                action: nil,
                keyEquivalent: ""
            )
            warn.isEnabled = false
            menu.addItem(warn)
            let openAX = NSMenuItem(
                title: "Abrir Accesibilidad en Ajustes…",
                action: #selector(openAccessibilitySettings),
                keyEquivalent: ""
            )
            openAX.target = self
            menu.addItem(openAX)
            menu.addItem(NSMenuItem.separator())
        }

        let peers = multipeer.connectedPeers
        if peers.isEmpty {
            let waiting = NSMenuItem(title: "Buscando iPhone…", action: nil, keyEquivalent: "")
            waiting.isEnabled = false
            menu.addItem(waiting)
        } else {
            for peer in peers {
                let item = NSMenuItem(title: "✓ \(peer.displayName)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }

        menu.addItem(NSMenuItem.separator())

        let reopenAX = NSMenuItem(
            title: "Solicitar permiso de Accesibilidad…",
            action: #selector(requestAccessibility),
            keyEquivalent: ""
        )
        reopenAX.target = self
        menu.addItem(reopenAX)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Salir", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        return menu
    }

    @objc private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func requestAccessibility() {
        KeyInjector.requestPermission()
        statusItem?.menu = buildMenu()
    }

    @objc private func quitApp() {
        multipeer.stop()
        NSApplication.shared.terminate(nil)
    }
}
