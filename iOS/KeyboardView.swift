import SwiftUI
import UIKit

struct KeyboardView: View {
    @StateObject private var manager = MultipeerManager(role: .clientBrowser)
    @State private var inputText = " " // Espacio como ancla para detectar borrado
    @State private var isKeyboardOpen = false
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .top) {
            // Fondo que llena TODA la pantalla
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                StatusBar(manager: manager)
                
                if case .connected = manager.linkState {
                    TrackpadView(manager: manager, isKeyboardOpen: $isKeyboardOpen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray6).opacity(0.4))
                } else {
                    ConnectionWaitingView()
                }
                
                // Botón inferior más sutil
                if !isKeyboardOpen && manager.linkState != .searching {
                    Button(action: { isKeyboardOpen = true }) {
                        Label("Abrir Teclado", systemImage: "keyboard")
                            .font(.system(size: 14, weight: .semibold))
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                    }
                }
            }
            
            // Captura de teclado nativo usando UIViewRepresentable
            HiddenKeyCaptureView(
                onKeyPress: { char in
                    for c in char {
                        manager.send(command: .keyboard(char: String(c)))
                    }
                },
                onDelete: {
                    manager.sendSpecial(.delete)
                }
            )
            .focused($isFocused)
            .frame(width: 1, height: 1)
            .opacity(0)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        FunctionKeyBar(manager: manager)
                        Spacer()
                        Button { isKeyboardOpen = false } label: {
                            Image(systemName: "keyboard.chevron.compact.down").bold()
                        }
                    }
                }
        }
        .onAppear {
            manager.start()
            isKeyboardOpen = true // Auto-open on start if needed
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            manager.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: isKeyboardOpen) { _, newValue in
            isFocused = newValue
        }
        .onChange(of: isFocused) { _, newValue in
            isKeyboardOpen = newValue
        }
    }
}

// MARK: - Connection Waiting View

private struct ConnectionWaitingView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "laptopcomputer.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("Esperando Mac")
                    .font(.title3.bold())
                Text("Acepta la invitación en tu Mac para comenzar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 50)
            }
            Spacer()
        }
    }
}

// MARK: - Status Bar

private struct StatusBar: View {
    @ObservedObject var manager: MultipeerManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.5), radius: 4)

            Text(statusLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 60) // Padding manual para quedar debajo de la Dynamic Island
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
    }

    private var statusColor: Color {
        switch manager.linkState {
        case .searching: return .orange
        case .connecting: return .orange
        case .connected: return .green
        case .disconnected: return .red
        }
    }

    private var statusLabel: String {
        switch manager.linkState {
        case .searching: return "Buscando..."
        case .connecting: return "Conectando..."
        case .connected(let name): return "Conectado a \(name ?? "Mac")"
        case .disconnected: return "Desconectado"
        }
    }
}

// MARK: - Function Key Bar

private struct FunctionKeyBar: View {
    @ObservedObject var manager: MultipeerManager

    var body: some View {
        HStack(spacing: 4) {
            FunctionKey(label: "⇥", accessibilityLabel: "Tab") { manager.sendSpecial(.tab) }
            FunctionKey(label: "⌫", accessibilityLabel: "Borrar") { manager.sendSpecial(.delete) }

            Spacer(minLength: 4)

            FunctionKey(label: "←", accessibilityLabel: "Flecha izquierda") { manager.sendSpecial(.arrowLeft) }
            FunctionKey(label: "→", accessibilityLabel: "Flecha derecha") { manager.sendSpecial(.arrowRight) }
            FunctionKey(label: "↑", accessibilityLabel: "Flecha arriba") { manager.sendSpecial(.arrowUp) }
            FunctionKey(label: "↓", accessibilityLabel: "Flecha abajo") { manager.sendSpecial(.arrowDown) }

            Spacer(minLength: 4)

            FunctionKey(label: "↵", accessibilityLabel: "Retorno", accent: true) { manager.sendSpecial(.returnKey) }
        }
    }
}

// MARK: - Function Key

private struct FunctionKey: View {
    let label: String
    var accessibilityLabel: String
    let action: () -> Void
    var accent: Bool = false
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    init(label: String, accessibilityLabel: String, accent: Bool = false, action: @escaping () -> Void) {
        self.label = label
        self.accessibilityLabel = accessibilityLabel
        self.accent = accent
        self.action = action
    }

    var body: some View {
        Button {
            haptic.prepare()
            haptic.impactOccurred()
            action()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .frame(minWidth: 32, minHeight: 36)
                .frame(maxWidth: 44)
                .background(accent ? Color.accentColor.opacity(0.18) : Color(.systemGray5))
                .foregroundStyle(accent ? Color.accentColor : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Trackpad View

private struct TrackpadView: View {
    @ObservedObject var manager: MultipeerManager
    @Binding var isKeyboardOpen: Bool
    @State private var lastDragTranslation: CGSize = .zero
    @State private var accumulatedDelta: CGSize = .zero
    @State private var lastSendTime: Date = Date()

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            // Gesto de bajar teclado (swipe rápido hacia abajo)
                            if value.translation.height > 100 && isKeyboardOpen {
                                isKeyboardOpen = false
                                return
                            }

                            let dx = value.translation.width - lastDragTranslation.width
                            let dy = value.translation.height - lastDragTranslation.height
                            lastDragTranslation = value.translation

                            accumulatedDelta.width += dx
                            accumulatedDelta.height += dy

                            if Date().timeIntervalSince(lastSendTime) > 0.016 {
                                manager.send(command: .mouseMove(dx: Double(accumulatedDelta.width), dy: Double(accumulatedDelta.height)))
                                accumulatedDelta = .zero
                                lastSendTime = Date()
                            }
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                            if accumulatedDelta != .zero {
                                manager.send(command: .mouseMove(dx: Double(accumulatedDelta.width), dy: Double(accumulatedDelta.height)))
                                accumulatedDelta = .zero
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        manager.send(command: .mouseClick(button: .left))
                    }
                )

            VStack {
                Text("Trackpad")
                    .foregroundStyle(.secondary.opacity(0.15))
                    .font(.system(size: 40, weight: .black))
                Text("Desliza para mover • Toca para click\nDesliza hacia abajo para cerrar teclado")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary.opacity(0.3))
            }

            // Botón Click Derecho discreto
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        manager.send(command: .mouseClick(button: .right))
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "cursorarrow.and.square.on.square.dashed")
                                .font(.system(size: 20))
                            Text("R-Click")
                                .font(.system(size: 10, weight: .bold))
                        }
                        .frame(width: 64, height: 64)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .padding(24)
                }
            }
        }
    }
}

// MARK: - Native Keyboard Capture

class KeyCaptureTextField: UITextField {
    var onDelete: (() -> Void)?
    
    override func deleteBackward() {
        onDelete?()
        super.deleteBackward()
    }
}

struct HiddenKeyCaptureView: UIViewRepresentable {
    var onKeyPress: (String) -> Void
    var onDelete: () -> Void

    func makeUIView(context: Context) -> KeyCaptureTextField {
        let textField = KeyCaptureTextField()
        textField.delegate = context.coordinator
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.spellCheckingType = .no
        textField.keyboardType = .default
        
        // Hacerlo completamente invisible
        textField.textColor = .clear
        textField.tintColor = .clear
        textField.backgroundColor = .clear
        
        textField.onDelete = onDelete
        return textField
    }

    func updateUIView(_ uiView: KeyCaptureTextField, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: HiddenKeyCaptureView

        init(_ parent: HiddenKeyCaptureView) {
            self.parent = parent
        }

        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            if !string.isEmpty {
                parent.onKeyPress(string)
            }
            return false // Prevenir que el textfield guarde estado, manteniéndolo vacío
        }
    }
}

#Preview {
    KeyboardView()
}
