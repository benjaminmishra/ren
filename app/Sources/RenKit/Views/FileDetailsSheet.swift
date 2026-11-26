import SwiftUI

struct FileDetailsSheet: View {
    @ObservedObject var vm: CleanerViewModel
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            Theme.slateBackground.opacity(0.88)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("Scanned File Targets")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Spacer()
                    Button("Done") { isPresented = false }
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding()

                List {
                    ForEach(vm.items) { item in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: { vm.selectedIds.contains(item.id) },
                                set: { _ in vm.toggleSelection(for: item.id) }
                            ))
                            .labelsHidden()

                            Circle()
                                .fill(item.category.color)
                                .frame(width: 7, height: 7)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white)
                                Text(item.path)
                                    .font(.system(size: 10))
                                    .foregroundColor(Color.white.opacity(0.4))
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(item.formattedSize)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(item.category.color)
                        }
                        .padding(.vertical, 2)
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 540, minHeight: 360)
    }
}
