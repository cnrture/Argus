import SwiftUI

struct NotchContainerView: View {
    let appState: AppState
    let notchRect: CGRect
    let screenSize: CGSize
    var onExpandChange: ((Bool) -> Void)?

    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            if appState.panelState != .hidden {
                if appState.isExpanded {
                    expandedContent
                        .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
                } else {
                    compactContent
                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
                }
            }
        }
        .frame(width: screenSize.width, height: 750)
        .animation(appState.isExpanded ? openAnimation : closeAnimation, value: appState.isExpanded)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: appState.panelState)
    }

    @ViewBuilder
    private var compactContent: some View {
        if let session = appState.activeSession {
            CompactView(
                session: session,
                sessionCount: appState.sessions.count,
                notchWidth: notchRect.width
            )
            .offset(y: notchRect.height)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        ExpandedOverviewView(
            appState: appState,
            notchWidth: notchRect.width
        )
        .offset(y: notchRect.height)
    }
}
