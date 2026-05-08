import Foundation
import MultipeerConnectivity
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// Rol: Mac anuncia (`advertiser`), iPhone busca e invita (`browser`). Mismo `serviceType` en ambos.
enum MultipeerRole {
    case hostAdvertiser
    case clientBrowser
}

/// Estado de enlace para la UI del cliente (iPhone).
enum MultipeerLinkState: Equatable {
    case searching
    case connecting(peerName: String?)
    case connected(peerName: String?)
    case disconnected
}

final class MultipeerManager: NSObject, ObservableObject {
    let serviceType = "mi-teclado"

    private let myPeerID: MCPeerID
    private let role: MultipeerRole

    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var isStopping = false

    @Published private(set) var connectedPeers: [MCPeerID] = []
    @Published private(set) var receivedText: String = ""
    @Published private(set) var linkState: MultipeerLinkState = .searching

    init(role: MultipeerRole) {
        self.role = role
        switch role {
        case .hostAdvertiser:
#if os(macOS)
            let name = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
            self.myPeerID = MCPeerID(displayName: name)
#else
            self.myPeerID = MCPeerID(displayName: "Mac")
#endif
        case .clientBrowser:
#if canImport(UIKit)
            self.myPeerID = MCPeerID(displayName: UIDevice.current.name)
#else
            self.myPeerID = MCPeerID(displayName: "iOS")
#endif
        }

        super.init()

        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
    }

    func start() {
        isStopping = false
        if role == .clientBrowser {
            DispatchQueue.main.async { self.linkState = .searching }
        }
        switch role {
        case .hostAdvertiser:
            startAdvertising()
        case .clientBrowser:
            startBrowsing()
        }
    }

    func stop() {
        isStopping = true
        advertiser?.stopAdvertisingPeer()
        advertiser?.delegate = nil
        advertiser = nil

        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil

        session.disconnect()
        DispatchQueue.main.async {
            self.connectedPeers = []
            if self.role == .clientBrowser {
                self.linkState = .disconnected
            }
        }
    }

    func send(text: String) {
        guard !session.connectedPeers.isEmpty else {
            print("No hay peers conectados")
            return
        }
        guard let data = text.data(using: .utf8) else { return }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Error enviando: \(error.localizedDescription)")
        }
    }

    func sendSpecial(_ key: SpecialKey) {
        send(text: key.rawValue)
    }

    private func startAdvertising() {
        guard advertiser == nil else { return }
        let adv = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        adv.delegate = self
        advertiser = adv
        adv.startAdvertisingPeer()
    }

    private func startBrowsing() {
        guard browser == nil else { return }
        if role == .clientBrowser {
            DispatchQueue.main.async { self.linkState = .searching }
        }
        let br = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        br.delegate = self
        browser = br
        br.startBrowsingForPeers()
    }

    /// Tras una caída, el browser vuelve a invitar al peer encontrado (`foundPeer`).
    private func restartBrowsingAfterDisconnect() {
        guard !isStopping, role == .clientBrowser else { return }
        browser?.stopBrowsingForPeers()
        browser?.delegate = nil
        browser = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self, !self.isStopping else { return }
            self.startBrowsing()
        }
    }

    /// Reinicia el anuncio en el Mac para aceptar nuevas invitaciones tras una desconexión.
    private func restartAdvertisingIfNeeded() {
        guard !isStopping, role == .hostAdvertiser else { return }
        if let adv = advertiser {
            adv.stopAdvertisingPeer()
            adv.startAdvertisingPeer()
        } else {
            startAdvertising()
        }
    }
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        print("Invitación recibida de: \(peerID.displayName)")
        
        if let confirmation = self.invitationHandler {
            confirmation(peerID) { [weak self] accepted in
                invitationHandler(accepted, accepted ? self?.session : nil)
            }
        } else {
            // Por seguridad, si no hay handler configurado, rechazamos por defecto.
            invitationHandler(false, nil)
        }
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        print("Encontré peer: \(peerID.displayName)")
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Perdí peer: \(peerID.displayName)")
    }
}

// MARK: - MCSessionDelegate

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                print("Conectado con: \(peerID.displayName)")
                if self.role == .clientBrowser {
                    self.linkState = .connected(peerName: peerID.displayName)
                }
            case .connecting:
                print("Conectando con: \(peerID.displayName)...")
                if self.role == .clientBrowser {
                    self.linkState = .connecting(peerName: peerID.displayName)
                }
            case .notConnected:
                print("Desconectado de: \(peerID.displayName)")
                if self.role == .clientBrowser {
                    self.linkState = .disconnected
                }
                if self.role == .clientBrowser, session.connectedPeers.isEmpty {
                    self.restartBrowsingAfterDisconnect()
                }
                if self.role == .hostAdvertiser {
                    self.restartAdvertisingIfNeeded()
                }
            @unknown default:
                break
            }
            self.connectedPeers = session.connectedPeers
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let callback = didReceiveData {
            callback(data, peerID)
        } else {
            // Comportamiento por defecto (ej. actualizar UI)
            if let text = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self.receivedText = text
                }
            }
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}

    func session(
        _ session: MCSession,
        didStartReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        with progress: Progress
    ) {}

    func session(
        _ session: MCSession,
        didFinishReceivingResourceWithName resourceName: String,
        fromPeer peerID: MCPeerID,
        at localURL: URL?,
        withError error: Error?
    ) {}
}
