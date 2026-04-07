import SwiftUI

struct DiffPreviewView: View {
    let diff: DiffPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // File path header
            Text(diff.filePath)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.04))

            // Diff lines
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(diff.deletions.enumerated()), id: \.offset) { _, line in
                        DiffLine(text: line, type: .deletion)
                    }
                    ForEach(Array(diff.additions.enumerated()), id: \.offset) { _, line in
                        DiffLine(text: line, type: .addition)
                    }
                }
            }
            .frame(maxHeight: 200)

            // Summary
            HStack(spacing: 8) {
                if diff.addedCount > 0 {
                    Text("+\(diff.addedCount)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                }
                if diff.deletedCount > 0 {
                    Text("−\(diff.deletedCount)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.red)
                }
                Text("satır değişiklik")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.black.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

private struct DiffLine: View {
    let text: String
    let type: DiffLineType

    enum DiffLineType {
        case addition, deletion
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(type == .addition ? "+" : "−")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(type == .addition ? .green : .red)
                .frame(width: 14)

            Text(text)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 2)
        .background(type == .addition ? Color.green.opacity(0.08) : Color.red.opacity(0.08))
    }
}
