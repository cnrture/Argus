import SwiftUI

struct MarkdownText: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(parseLines().enumerated()), id: \.offset) { _, element in
                element
            }
        }
    }

    private func parseLines() -> [AnyView] {
        let lines = text.components(separatedBy: "\n")
        var result: [AnyView] = []
        var inCodeBlock = false
        var codeLines: [String] = []

        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    result.append(AnyView(codeBlock(codeLines)))
                    codeLines.removeAll()
                }
                inCodeBlock.toggle()
                continue
            }

            if inCodeBlock {
                codeLines.append(line)
                continue
            }

            if line.hasPrefix("## ") {
                let heading = String(line.dropFirst(3))
                result.append(AnyView(
                    Text(heading)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                ))
            } else if line.hasPrefix("# ") {
                let heading = String(line.dropFirst(2))
                result.append(AnyView(
                    Text(heading)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.top, 4)
                ))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let item = String(line.dropFirst(2))
                result.append(AnyView(
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.5))
                        inlineFormatted(item)
                    }
                    .padding(.leading, 8)
                ))
            } else if let match = line.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                let number = String(line[match]).trimmingCharacters(in: .whitespaces)
                let rest = String(line[match.upperBound...])
                result.append(AnyView(
                    HStack(alignment: .top, spacing: 6) {
                        Text(number)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.orange)
                        inlineFormatted(rest)
                    }
                    .padding(.leading, 4)
                ))
            } else if !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(AnyView(inlineFormatted(line)))
            }
        }

        return result
    }

    private func inlineFormatted(_ text: String) -> some View {
        var result = Text("")
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold: **text**
            if let boldRange = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
                let before = remaining[remaining.startIndex..<boldRange.lowerBound]
                if !before.isEmpty {
                    result = result + Text(before).foregroundColor(.white.opacity(0.8))
                }
                let inner = remaining[boldRange].dropFirst(2).dropLast(2)
                result = result + Text(inner).bold().foregroundColor(.white)
                remaining = remaining[boldRange.upperBound...]
            }
            // Inline code: `text`
            else if let codeRange = remaining.range(of: #"`(.+?)`"#, options: .regularExpression) {
                let before = remaining[remaining.startIndex..<codeRange.lowerBound]
                if !before.isEmpty {
                    result = result + Text(before).foregroundColor(.white.opacity(0.8))
                }
                let inner = remaining[codeRange].dropFirst(1).dropLast(1)
                result = result + Text(inner)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.orange.opacity(0.9))
                remaining = remaining[codeRange.upperBound...]
            }
            else {
                result = result + Text(remaining).foregroundColor(.white.opacity(0.8))
                break
            }
        }

        return result.font(.system(size: 12))
    }

    private func codeBlock(_ lines: [String]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.green.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}
