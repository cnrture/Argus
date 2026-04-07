import SwiftUI

struct PermissionView: View {
    let session: SessionInfo
    let permission: PermissionEvent
    let notchWidth: CGFloat
    var onAllow: () -> Void
    var onDeny: () -> Void
    var onAutoApprove: (String) -> Void

    @State private var autoApproveChecked = false
    @State private var showAllowButton = false
    @State private var showDenyButton = false

    private var expandedWidth: CGFloat {
        min(notchWidth * 3, 600)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                StatusDot(status: .waiting)
                Text(session.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text("— İzin Gerekli")
                    .font(.system(size: 13))
                    .foregroundStyle(.orange)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            // Tool description
            toolDescription
                .padding(.horizontal, 16)

            // Diff preview for Edit/Write
            if let diff = permission.diffPreview {
                DiffPreviewView(diff: diff)
                    .padding(.horizontal, 16)
            }

            // Auto-approve checkbox
            Toggle(isOn: $autoApproveChecked) {
                Text("Bu oturumda \(permission.toolName) için hep izin ver")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            .toggleStyle(.checkbox)
            .padding(.horizontal, 16)

            // Action buttons with staggered reveal
            HStack(spacing: 12) {
                Spacer()

                // Deny button
                Button(action: handleDeny) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Reddet")
                            .font(.system(size: 12, weight: .medium))
                        Text("(⌘N)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.red.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .opacity(showDenyButton ? 1 : 0)
                .offset(y: showDenyButton ? 0 : 5)

                // Allow button
                Button(action: handleAllow) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("İzin Ver")
                            .font(.system(size: 12, weight: .medium))
                        Text("(⌘Y)")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.green.opacity(0.15))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.green.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.green)
                .opacity(showAllowButton ? 1 : 0)
                .offset(y: showAllowButton ? 0 : 5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .frame(width: expandedWidth)
        .background(
            NotchShape(topCornerRadius: 19, bottomCornerRadius: 24)
                .fill(.black.opacity(0.95))
        )
        .overlay(
            NotchShape(topCornerRadius: 19, bottomCornerRadius: 24)
                .stroke(.orange.opacity(0.2), lineWidth: 0.5)
        )
        .onAppear {
            // Staggered button reveal: 50ms delay
            withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                showDenyButton = true
            }
            withAnimation(.easeOut(duration: 0.2).delay(0.15)) {
                showAllowButton = true
            }
        }
    }

    @ViewBuilder
    private var toolDescription: some View {
        switch permission.toolName {
        case "Bash":
            VStack(alignment: .leading, spacing: 6) {
                Text("Bash aracını çalıştırmak istiyor:")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))

                Text("$ \(permission.toolInput?["command"]?.stringValue ?? "")")
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black.opacity(0.4))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.white.opacity(0.08), lineWidth: 0.5)
                    )
            }

        case "Edit":
            Text("Edit: \(permission.toolInput?["file_path"]?.stringValue ?? "")")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

        case "Write":
            Text("Write: \(permission.toolInput?["file_path"]?.stringValue ?? "")")
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))

        default:
            Text("\(permission.toolName) aracını kullanmak istiyor")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func handleAllow() {
        if autoApproveChecked {
            onAutoApprove(permission.toolName)
        }
        onAllow()
    }

    private func handleDeny() {
        onDeny()
    }
}
