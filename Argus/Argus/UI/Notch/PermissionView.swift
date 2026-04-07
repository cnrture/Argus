import SwiftUI

struct PermissionView: View {
    let session: SessionInfo
    let permission: PermissionEvent
    let notchWidth: CGFloat
    var onAllow: () -> Void
    var onDeny: () -> Void
    var onAutoApprove: (String) -> Void

    @State private var showButtons = false

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
                Text("— \(L10n["permission.required"])")
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

            // Action buttons with staggered reveal
            HStack(spacing: 8) {
                Spacer()

                permButton(L10n["permission.deny"], icon: "xmark", shortcut: "⌘N", color: .red) {
                    handleDeny()
                }

                permButton(L10n["permission.allow"], icon: "checkmark", shortcut: "⌘Y", color: .green) {
                    handleAllow()
                }

                permButton(L10n["permission.allowAll"], icon: "checkmark.circle.fill", shortcut: nil, color: .blue) {
                    handleAllowAll()
                }
            }
            .opacity(showButtons ? 1 : 0)
            .offset(y: showButtons ? 0 : 5)
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
            withAnimation(.easeOut(duration: 0.2).delay(0.1)) {
                showButtons = true
            }
        }
    }

    private func permButton(_ title: String, icon: String, shortcut: String?, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                if let shortcut {
                    Text("(\(shortcut))")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.15)))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(color.opacity(0.3), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(color)
    }

    @ViewBuilder
    private var toolDescription: some View {
        switch permission.toolName {
        case "Bash":
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n["permission.tool.bash"])
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
            Text("\(permission.toolName) \(L10n["permission.tool.generic"])")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func handleAllow() {
        onAllow()
    }

    private func handleDeny() {
        onDeny()
    }

    private func handleAllowAll() {
        // onAutoApprove handles both the rule AND the response with updatedPermissions
        onAutoApprove(permission.toolName)
    }
}
