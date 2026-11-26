import SwiftUI
import AppKit

// MARK: - Centralized One Dark Pro / Monokai Theme Palette
public enum Theme {
    public static let slateBackground = Color(red: 0.11, green: 0.13, blue: 0.16)
    public static let textMuted = Color(red: 0.60, green: 0.65, blue: 0.72)
    public static let textSecondary = Color(red: 0.72, green: 0.76, blue: 0.82)
    public static let textDimmed = Color(red: 0.52, green: 0.57, blue: 0.64)

    public static let cyan = Color(red: 0.38, green: 0.69, blue: 0.94)
    public static let deepBlue = Color(red: 0.30, green: 0.50, blue: 0.90)
    public static let purple = Color(red: 0.78, green: 0.47, blue: 0.87)
    public static let amber = Color(red: 0.90, green: 0.75, blue: 0.48)
    public static let neonPink = Color(red: 0.98, green: 0.15, blue: 0.45)
    public static let lime = Color(red: 0.65, green: 0.89, blue: 0.18)
    public static let skyBlue = Color(red: 0.40, green: 0.85, blue: 0.94)
    public static let mint = Color(red: 0.30, green: 0.88, blue: 0.72)
    public static let orange = Color(red: 0.99, green: 0.59, blue: 0.12)

    public static let scanGradient: [Color] = [cyan, deepBlue]
    public static let trashGradient: [Color] = [neonPink, purple]
    public static let disabledGradient: [Color] = [Color.white.opacity(0.15), Color.white.opacity(0.08)]
    public static let logoGradient: [Color] = [cyan, mint, purple]
}

// MARK: - Minimal Swedish Geometric Mark for Ren
struct RenLogoMark: View {
    var size: CGFloat = 16

    var body: some View {
        let stroke = max(1.6, size * 0.13)
        let dotSize = max(3.2, size * 0.26)

        ZStack {
            Circle()
                .trim(from: 0.0, to: 0.84)
                .stroke(
                    AngularGradient(
                        colors: Theme.logoGradient,
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: stroke, lineCap: .round)
                )
                .rotationEffect(.degrees(-22))

            Circle()
                .fill(Theme.mint)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: Theme.mint.opacity(0.75), radius: 3)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Native AppKit Frosted Glass Window Backdrop
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .underWindowBackground
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Window Translucency Accessor
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window {
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                window.styleMask.insert(.fullSizeContentView)
                window.isMovableByWindowBackground = true
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

// MARK: - Liquid Glass Surface
struct LiquidGlassBackground: View {
    var cornerRadius: CGFloat = 12
    var isSelected: Bool = false
    var accentColor: Color = .white
    var intensity: Double = 1.0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            isSelected ? accentColor.opacity(0.18 * intensity) : Color.white.opacity(0.08 * intensity),
                            isSelected ? accentColor.opacity(0.05 * intensity) : Color.white.opacity(0.02 * intensity)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.15 * intensity), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 14)
                    .padding(.horizontal, 2)
                    .padding(.top, 1)
                Spacer()
            }

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            isSelected ? accentColor.opacity(0.65) : Color.white.opacity(0.38),
                            Color.white.opacity(0.10),
                            Color.black.opacity(0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(
            color: isSelected ? accentColor.opacity(0.25) : Color.black.opacity(0.14),
            radius: isSelected ? 8 : 5,
            x: 0,
            y: 2
        )
    }
}

// MARK: - Liquid Glass Button
struct LiquidGlassButton: View {
    let title: String
    let icon: String
    let gradientColors: [Color]
    let isEnabled: Bool
    var height: CGFloat = 36
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled ? gradientColors : [Color.white.opacity(0.08), Color.white.opacity(0.04)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(isHovered ? 0.45 : 0.32),
                                    Color.white.opacity(0.02)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: height * 0.42)
                        .padding(.horizontal, 3)
                        .padding(.top, 2)
                    Spacer()
                }

                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.70), Color.white.opacity(0.15), Color.black.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )

                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(title)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.white)
            }
            .frame(height: height)
            .shadow(
                color: isEnabled ? gradientColors.first?.opacity(isHovered ? 0.55 : 0.35) ?? .clear : .clear,
                radius: isHovered ? 12 : 7,
                y: 2
            )
            .scaleEffect(isHovered && isEnabled ? 1.015 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
    }
}
