import Foundation

/// Comandos `SPECIAL:*` enviados por el iPhone al Mac (ver tutorial 1.5 — Models.swift).
enum SpecialKey: String {
    case tab = "SPECIAL:TAB"
    case delete = "SPECIAL:DELETE"
    case returnKey = "SPECIAL:RETURN"
    case arrowLeft = "SPECIAL:ARROW_LEFT"
    case arrowRight = "SPECIAL:ARROW_RIGHT"
    case arrowUp = "SPECIAL:ARROW_UP"
    case arrowDown = "SPECIAL:ARROW_DOWN"
}
