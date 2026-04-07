import SwiftUI

struct SessionCard: View {
    let session: SessionInfo
    var isCompact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                StatusDot(status: session.status)

                Image(systemName: session.source.icon)
                    .font(.system(size: 10))
                    .foregroundStyle(session.source.color)

                Text(session.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()
            }

            if !isCompact {
                if session.isIdle {
                    Text("15 dk+ hareketsiz")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.4))
                } else if let statusText = session.lastStatusText {
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                } else if let lastTool = session.lastToolName {
                    Text("Son: \(lastTool)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.white.opacity(session.isIdle ? 0.03 : 0.06))
        )
        .opacity(session.isIdle ? 0.6 : 1.0)
    }
}
