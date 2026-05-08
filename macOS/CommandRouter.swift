import Foundation
import MultipeerConnectivity

/// Clase encargada de interpretar los comandos recibidos y delegar a los inyectores.
final class CommandRouter: Sendable {
    private let keyboardInjector: any KeyboardInjecting
    private let mouseInjector: any MouseInjecting
    
    init(keyboardInjector: any KeyboardInjecting, mouseInjector: any MouseInjecting) {
        self.keyboardInjector = keyboardInjector
        self.mouseInjector = mouseInjector
    }
    
    func handle(data: Data, from peerID: MCPeerID) {
        guard let command = try? JSONDecoder().decode(DeviceCommand.self, from: data) else {
            return
        }
        
        Task {
            switch command {
            case .keyboard(let char):
                await keyboardInjector.inject(string: char)
            case .specialKey(let key):
                await keyboardInjector.inject(special: key)
            case .mouseMove(let dx, let dy):
                await mouseInjector.move(dx: dx, dy: dy)
            case .mouseClick(let button):
                await mouseInjector.click(button: button)
            case .mouseScroll(let dy):
                await mouseInjector.scroll(dy: dy)
            }
        }
    }
}
