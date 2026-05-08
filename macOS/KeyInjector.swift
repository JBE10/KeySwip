import ApplicationServices
import CoreGraphics
import Foundation

enum KeyInjector {
    static func hasPermission() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private static let injectionQueue = DispatchQueue(label: "com.keyswip.keyinjection", qos: .userInteractive)

    /// Inyecta un string de forma secuencial usando una cola serial para evitar desorden (VULN-003).
    static func inject(string: String) {
        guard hasPermission() else {
            print("Sin permiso de Accesibilidad")
            return
        }
        
        injectionQueue.async {
            for character in string {
                inject(character: character)
                // Pequeño retraso para estabilidad en aplicaciones destino
                Thread.sleep(forTimeInterval: 0.005)
            }
        }
    }

    static func inject(character: Character) {
        guard hasPermission() else {
            print("Sin permiso de Accesibilidad")
            return
        }

        switch character {
        case "\n":
            injectKeyCode(0x24)
            return
        case "\t":
            injectKeyCode(0x30)
            return
        case " ":
            injectKeyCode(0x31)
            return
        default:
            injectUnicodeString(String(character))
        }
    }

    static func inject(special key: SpecialKey) {
        guard hasPermission() else {
            print("Sin permiso de Accesibilidad")
            return
        }
        switch key {
        case .tab: injectKeyCode(0x30)
        case .delete: injectKeyCode(0x33)
        case .returnKey: injectKeyCode(0x24)
        case .arrowLeft: injectKeyCode(0x7B)
        case .arrowRight: injectKeyCode(0x7C)
        case .arrowUp: injectKeyCode(0x7E)
        case .arrowDown: injectKeyCode(0x7D)
        }
    }

    private static func injectUnicodeString(_ string: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        var utf16 = Array(string.utf16)
        utf16.withUnsafeMutableBufferPointer { buffer in
            guard let base = buffer.baseAddress, buffer.count > 0 else { return }

            let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
            let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            keyDown?.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            keyUp?.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: base)
            keyDown?.post(tap: .cgAnnotatedSessionEventTap)
            keyUp?.post(tap: .cgAnnotatedSessionEventTap)
        }
    }

    private static func injectKeyCode(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
