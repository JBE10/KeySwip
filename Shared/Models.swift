import Foundation

/// Comandos estructurados enviados entre dispositivos (iPhone -> Mac).
enum DeviceCommand: Codable {
    case keyboard(char: String)
    case specialKey(SpecialKey)
    case mouseMove(dx: Double, dy: Double)
    case mouseClick(button: MouseButton)
    case mouseScroll(dy: Int)
}

enum MouseButton: Codable {
    case left, right
}

/// Comandos `SPECIAL:*` enviados por el iPhone al Mac.
enum SpecialKey: String, Codable {
    case tab = "SPECIAL:TAB"
    case delete = "SPECIAL:DELETE"
    case returnKey = "SPECIAL:RETURN"
    case arrowLeft = "SPECIAL:ARROW_LEFT"
    case arrowRight = "SPECIAL:ARROW_RIGHT"
    case arrowUp = "SPECIAL:ARROW_UP"
    case arrowDown = "SPECIAL:ARROW_DOWN"
}
