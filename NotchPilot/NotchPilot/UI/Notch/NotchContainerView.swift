import SwiftUI

struct NotchContainerView: View {
    let appState: AppState
    let settingsStore: SettingsStore?
    let notchRect: CGRect
    let screenSize: CGSize
    var onExpandChange: ((Bool) -> Void)?
    var onPermissionAllow: ((String) -> Void)?
    var onPermissionDeny: ((String) -> Void)?
    var onAutoApprove: ((String, String) -> Void)?
    var onQuestionAnswer: ((String, String) -> Void)?
    var onPlanApprove: ((String, String?) -> Void)?
    var onPlanReject: ((String, String?) -> Void)?
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var onJumpToSession: ((String) -> Void)?

    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            if let completionSession = appState.completionSession {
                CompletionCardView(
                    session: completionSession,
                    notchWidth: notchRect.width,
                    onDismiss: { appState.completionSession = nil },
                    onJump: { onJumpToSession?(completionSession.id) }
                )
                .offset(y: notchRect.height)
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            } else if appState.panelState != .hidden {
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
                notchWidth: notchRect.width,
                petStyle: settingsStore?.petStyle ?? .dot,
                accentColor: settingsStore?.accentColor ?? .orange,
                showBorder: settingsStore?.showBorder ?? true
            )
            .opacity(appState.isHovered ? 1.0 : (settingsStore?.idleOpacity ?? 0.45))
            .animation(.easeInOut(duration: 0.2), value: appState.isHovered)
            .offset(y: notchRect.height)
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if let session = appState.activeSession {
            if session.pendingPermission, let permission = appState.activePermission {
                PermissionView(
                    session: session,
                    permission: permission,
                    notchWidth: notchRect.width,
                    onAllow: { onPermissionAllow?(permission.id) },
                    onDeny: { onPermissionDeny?(permission.id) },
                    onAutoApprove: { toolName in onAutoApprove?(session.id, toolName) }
                )
                .offset(y: notchRect.height)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            } else if session.pendingQuestion, let question = appState.activeQuestion {
                QuestionView(
                    session: session,
                    question: question,
                    notchWidth: notchRect.width,
                    onAnswer: { answer in onQuestionAnswer?(question.id, answer) }
                )
                .offset(y: notchRect.height)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            } else if session.pendingPlan, let plan = appState.activePlan {
                PlanReviewView(
                    session: session,
                    plan: plan,
                    notchWidth: notchRect.width,
                    onApprove: { feedback in onPlanApprove?(plan.id, feedback) },
                    onReject: { feedback in onPlanReject?(plan.id, feedback) }
                )
                .offset(y: notchRect.height)
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity
                ))
            } else {
                overviewView
            }
        } else {
            overviewView
        }
    }

    private var overviewView: some View {
        ExpandedOverviewView(
            appState: appState,
            notchWidth: notchRect.width,
            onOpenSettings: onOpenSettings,
            onQuit: onQuit,
            onJumpToSession: onJumpToSession
        )
        .offset(y: notchRect.height)
    }
}
