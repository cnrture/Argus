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
    var onCardDismissed: (() -> Void)?
    var onWelcomeInstallHooks: (() -> Void)?
    var onWelcomeFinish: (() -> Void)?

    private let openAnimation = Animation.spring(response: 0.42, dampingFraction: 0.8, blendDuration: 0)
    private let closeAnimation = Animation.spring(response: 0.45, dampingFraction: 1.0, blendDuration: 0)

    private var shouldMaskMenuBar: Bool {
        appState.errorInfo != nil ||
        appState.completionSession != nil ||
        appState.isWelcomeActive ||
        (appState.panelState != .hidden && appState.isExpanded)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear

            // Menu bar mask: notch yüksekliğinde siyah şerit, notch'un iki yanını kapatır
            if shouldMaskMenuBar {
                Rectangle()
                    .fill(Color.black)
                    .frame(width: screenSize.width, height: notchRect.height)
                    .frame(maxWidth: .infinity, alignment: .top)
                    .transition(.opacity)
            }

            // Welcome steps (highest priority when active)
            if appState.isWelcomeActive {
                WelcomeStepsView(
                    appState: appState,
                    notchWidth: notchRect.width,
                    notchHeight: notchRect.height,
                    accentColor: settingsStore?.accentColor ?? .orange,
                    onInstallHooks: onWelcomeInstallHooks,
                    onFinish: onWelcomeFinish
                )
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top)))
            }
            // Error card (highest priority)
            else if let error = appState.errorInfo {
                ErrorCardView(
                    errorType: error.type,
                    errorMessage: error.message,
                    sessionTitle: error.sessionTitle,
                    notchWidth: notchRect.width,
                    onDismiss: {
                        appState.errorInfo = nil
                        onCardDismissed?()
                    }
                )
                .padding(.top, notchRect.height)
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            }
            // Completion card
            else if let completionSession = appState.completionSession {
                CompletionCardView(
                    session: completionSession,
                    notchWidth: notchRect.width,
                    onDismiss: {
                        appState.completionSession = nil
                        onCardDismissed?()
                    },
                    onJump: { onJumpToSession?(completionSession.id) }
                )
                .padding(.top, notchRect.height)
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .top)))
            }
            else if appState.panelState != .hidden {
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
                notchHeight: notchRect.height,
                petStyle: settingsStore?.petStyle ?? .dot,
                accentColor: settingsStore?.accentColor ?? .orange,
                showBorder: settingsStore?.showBorder ?? true,
                widthMultiplier: CGFloat(settingsStore?.barWidth.multiplier ?? 1.5),
                cornerRadiusValue: CGFloat(settingsStore?.cornerRadius ?? 14),
                fontSizeValue: CGFloat(settingsStore?.fontSize ?? 12),
                horizontalOffset: CGFloat((settingsStore?.barOffset ?? 0) * 100)
            )
            .opacity(appState.isHovered ? 1.0 : (settingsStore?.idleOpacity ?? 0.45))
            .animation(.easeInOut(duration: 0.2), value: appState.isHovered)
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
                .padding(.top, notchRect.height)
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
                .padding(.top, notchRect.height)
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
                .padding(.top, notchRect.height)
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
        .padding(.top, notchRect.height)
    }
}
