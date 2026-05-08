import Foundation
import CoreGraphics
import ApplicationServices

protocol MouseInjecting: Sendable {
    func move(dx: Double, dy: Double) async
    func click(button: MouseButton) async
    func scroll(dy: Int) async
}

actor MacOSMouseInjector: MouseInjecting {
    
    private func hasPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func move(dx: Double, dy: Double) async {
        guard hasPermission() else { return }
        
        let maxDelta: CGFloat = 500.0
        let clampedDX = max(min(CGFloat(dx), maxDelta), -maxDelta)
        let clampedDY = max(min(CGFloat(dy), maxDelta), -maxDelta)
        
        guard let currentEvent = CGEvent(source: nil) else { return }
        let currentLocation = currentEvent.location
        let newLocation = CGPoint(x: currentLocation.x + (clampedDX * 1.5), y: currentLocation.y + (clampedDY * 1.5))

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let moveEvent = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: newLocation, mouseButton: .left)
        moveEvent?.post(tap: .cghidEventTap)
    }

    func click(button: MouseButton) async {
        guard hasPermission() else { return }
        guard let currentEvent = CGEvent(source: nil) else { return }
        let location = currentEvent.location
        
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        
        let downType: CGEventType = (button == .left) ? .leftMouseDown : .rightMouseDown
        let upType: CGEventType = (button == .left) ? .leftMouseUp : .rightMouseUp
        let cgButton: CGMouseButton = (button == .left) ? .left : .right
        
        let downEvent = CGEvent(mouseEventSource: source, mouseType: downType, mouseCursorPosition: location, mouseButton: cgButton)
        let upEvent = CGEvent(mouseEventSource: source, mouseType: upType, mouseCursorPosition: location, mouseButton: cgButton)
        
        downEvent?.post(tap: .cghidEventTap)
        upEvent?.post(tap: .cghidEventTap)
    }
    
    func scroll(dy: Int) async {
        guard hasPermission() else { return }
        
        let maxScroll: Int32 = 100
        let clampedDY = max(min(Int32(dy), maxScroll), -maxScroll)
        
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1, wheel1: clampedDY, wheel2: 0, wheel3: 0)
        scrollEvent?.post(tap: .cghidEventTap)
    }
}
