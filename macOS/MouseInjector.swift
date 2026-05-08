import ApplicationServices
import CoreGraphics
import Foundation

enum MouseInjector {
    static func hasPermission() -> Bool {
        AXIsProcessTrusted()
    }

    static func move(dx: CGFloat, dy: CGFloat) {
        guard hasPermission() else { return }
        guard let currentEvent = CGEvent(source: nil) else { return }
        let currentLocation = currentEvent.location
        let newLocation = CGPoint(x: currentLocation.x + dx, y: currentLocation.y + dy)

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: newLocation, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }

    static func clickLeft() {
        guard hasPermission() else { return }
        guard let currentEvent = CGEvent(source: nil) else { return }
        let location = currentEvent.location
        
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let downEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseDown, mouseCursorPosition: location, mouseButton: .left)
        let upEvent = CGEvent(mouseEventSource: source, mouseType: .leftMouseUp, mouseCursorPosition: location, mouseButton: .left)
        
        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }

    static func clickRight() {
        guard hasPermission() else { return }
        guard let currentEvent = CGEvent(source: nil) else { return }
        let location = currentEvent.location
        
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let downEvent = CGEvent(mouseEventSource: source, mouseType: .rightMouseDown, mouseCursorPosition: location, mouseButton: .right)
        let upEvent = CGEvent(mouseEventSource: source, mouseType: .rightMouseUp, mouseCursorPosition: location, mouseButton: .right)
        
        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }
    
    static func scroll(dy: Int32) {
        guard hasPermission() else { return }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        let scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1, wheel1: dy, wheel2: 0, wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }
    
    static func handle(command: String) {
        let parts = command.split(separator: ":")
        guard parts.count >= 2, parts[0] == "MOUSE" else { return }
        
        let action = parts[1]
        switch action {
        case "MOVE":
            if parts.count == 4, 
               let dx = Double(parts[2]), 
               let dy = Double(parts[3]) {
                
                // VULN-002: Limitamos el delta máximo para evitar saltos bruscos malintencionados
                let maxDelta: CGFloat = 500.0
                let clampedDX = max(min(CGFloat(dx), maxDelta), -maxDelta)
                let clampedDY = max(min(CGFloat(dy), maxDelta), -maxDelta)
                
                // Multiplicador de sensibilidad (ajustado)
                move(dx: clampedDX * 1.5, dy: clampedDY * 1.5)
            }
        case "CLICK":
            if parts.count == 3 {
                if parts[2] == "LEFT" {
                    clickLeft()
                } else if parts[2] == "RIGHT" {
                    clickRight()
                }
            }
        case "SCROLL":
            if parts.count == 3, let dy = Int32(parts[2]) {
                // Limitamos el scroll
                let maxScroll: Int32 = 100
                let clampedDY = max(min(dy, maxScroll), -maxScroll)
                scroll(dy: clampedDY)
            }
        default:
            break
        }
    }
}
