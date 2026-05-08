import SwiftUI
import UIKit

struct KeyboardView: View {
    @StateObject private var manager = MultipeerManager(role: .clientBrowser)
    @State private var inputText = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            StatusBar(manager: manager)

            if case .connected = manager.linkState {
                TrackpadView(manager: manager)
                    .frame(maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                Button(action: {
                    isFocused = true
                }) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Abrir Teclado")
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .foregroundStyle(.primary)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .padding(.horizontal, 16)

                    VStack(spacing: 16) {
                        Image(systemName: "laptopcomputer.slash")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("Abrí la app en tu Mac")
                            .font(.headline)
                        Text("Asegurate de que el Mac y el iPhone estén en la misma red Wi‑Fi.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: min(160, UIScreen.main.bounds.height * 0.22))
                .contentShape(Rectangle())
                .onTapGesture { isFocused = true }
            }

            Spacer(minLength: 8)

            TextField("", text: $inputText)
                .focused($isFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .opacity(0.01)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
                .onChange(of: inputText) { _, newValue in
                    guard !newValue.isEmpty else { return }
                    for ch in newValue {
                        manager.send(text: String(ch))
                    }
                    inputText = ""
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        FunctionKeyBar(manager: manager)
                    }
                }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .onAppear {
            manager.start()
            isFocused = true
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            manager.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }
}

private struct StatusBar: View {
    @ObservedObject var manager: MultipeerManager

    var body: some View {
        HStack(spacing: 8) {
            Group {
                switch manager.linkState {
                case .searching:
                    SearchingPulseDot()
                case .connecting:
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                case .connected:
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                case .disconnected:
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }

            Text(statusLabel)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(Color(.separator))
        }
        .animation(.easeInOut(duration: 0.3), value: manager.linkState)
    }

    private var statusLabel: String {
        switch manager.linkState {
        case .searching:
            return "Buscando Mac..."
        case .connecting:
            return "Conectando..."
        case .connected(let name):
            return "Conectado a \(name ?? "Mac")"
        case .disconnected:
            return "Mac desconectado"
        }
    }
}

private struct SearchingPulseDot: View {
    @State private var animate = false

    var body: some View {
        Circle()
            .fill(Color.orange)
            .frame(width: 8, height: 8)
            .scaleEffect(animate ? 1.3 : 1.0)
            .opacity(animate ? 0.5 : 1.0)
            .onAppear { animate = true }
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: animate)
    }
}

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
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

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
                .frame(maxWidth: 40)
                .background(accent ? Color.accentColor.opacity(0.18) : Color(.systemGray5))
                .foregroundStyle(accent ? Color.accentColor : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

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
                                manager.send(text: "MOUSE:MOVE:\(accumulatedDelta.width):\(accumulatedDelta.height)")
                                accumulatedDelta = .zero
                                lastSendTime = Date()
                            }
                        }
                        .onEnded { _ in
                            lastDragTranslation = .zero
                            if accumulatedDelta != .zero {
                                manager.send(text: "MOUSE:MOVE:\(accumulatedDelta.width):\(accumulatedDelta.height)")
                                accumulatedDelta = .zero
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture().onEnded {
                        manager.send(text: "MOUSE:CLICK:LEFT")
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
                        manager.send(text: "MOUSE:CLICK:RIGHT")
                    } label: {
                        VStack {
                            Image(systemName: "cursorarrow.and.square.on.square.dashed")
                            Text("R-Click").font(.system(size: 10, weight: .bold))
                        }
                        .frame(width: 64, height: 64)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.secondary.opacity(0.2), lineWidth: 1))
                    }
                    .padding(24)
                }
            }
        }
    }
}

#Preview {
    KeyboardView()
}
