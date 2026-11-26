import SwiftUI
import AppKit

struct AboutSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            Theme.slateBackground.opacity(0.90)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.slateBackground.opacity(0.9))
                        .frame(width: 68, height: 68)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: Theme.cyan.opacity(0.22), radius: 12, y: 4)

                    RenLogoMark(size: 40)
                }
                .padding(.top, 4)

                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Ren")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("v\(AppInfo.version)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(Theme.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.cyan.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    Text("Swedish for clean, pure.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.mint.opacity(0.85))
                }

                Text("Lightweight open-source macOS cleaner built with SwiftUI & Rust. Files are always moved safely to Trash with zero telemetry.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)

                HStack(spacing: 10) {
                    linkPill(title: "GitHub", icon: "chevron.left.forwardslash.chevron.right", url: AppInfo.repoURL)
                    linkPill(title: "Releases", icon: "arrow.down.circle", url: AppInfo.releasesURL)
                }

                Text("MIT License · © 2026 Benjamin Mishra")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textMuted.opacity(0.65))

                LiquidGlassButton(
                    title: "Done",
                    icon: "checkmark",
                    gradientColors: Theme.scanGradient,
                    isEnabled: true,
                    height: 30,
                    action: { isPresented = false }
                )
                .frame(width: 110)
                .keyboardShortcut(.defaultAction)
            }
            .padding(22)
        }
        .frame(width: 310, height: 305)
    }

    private func linkPill(title: String, icon: String, url: URL) -> some View {
        Button(action: { NSWorkspace.shared.open(url) }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
            }
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(LiquidGlassBackground(cornerRadius: 12, intensity: 0.9))
        }
        .buttonStyle(.plain)
    }
}
