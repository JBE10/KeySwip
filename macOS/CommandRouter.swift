import Foundation
import MultipeerConnectivity

/// Clase encargada de interpretar los mensajes recibidos del iPhone y delegar a los inyectores.
/// Cumple con SRP al separar la interpretación de comandos de la comunicación de red.
final class CommandRouter {
    func handle(data: Data, from peerID: MCPeerID) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        
        print("Procesando comando de \(peerID.displayName): \(text)")
        
        if text.hasPrefix("MOUSE:") {
            MouseInjector.handle(command: text)
        } else if let special = SpecialKey(rawValue: text) {
            KeyInjector.inject(special: special)
        } else {
            KeyInjector.inject(string: text)
        }
    }
}
