import Foundation
import CoreGraphics
import ApplicationServices

protocol KeyboardInjecting: Sendable {
    func inject(string: String) async
    func inject(character: Character) async
    func inject(special: SpecialKey) async
}

actor MacOSKeyboardInjector: KeyboardInjecting {
    
    private func hasPermission() -> Bool {
        AXIsProcessTrusted()
    }

    func inject(string: String) async {
        guard hasPermission() else { return }
        
        for character in string {
            await inject(character: character)
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func inject(character: Character) async {
        guard hasPermission() else { return }

        switch character {
        case "\n":
            injectKeyCode(0x24)
        case "\t":
            injectKeyCode(0x30)
        case " ":
            injectKeyCode(0x31)
        default:
            injectUnicodeString(String(character))
        }
    }

    func inject(special key: SpecialKey) async {
        guard hasPermission() else { return }
        
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

    private func injectUnicodeString(_ string: String) {
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

    private func injectKeyCode(_ keyCode: CGKeyCode, flags: CGEventFlags = []) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = flags
        keyUp?.flags = flags
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
