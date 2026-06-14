import LocalDictateCore
import SwiftUI

struct PermissionRowsView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        PermissionRow(
            title: "Microphone",
            state: model.permissions.microphone,
            detail: "Needed to record dictation.",
            actionTitle: model.permissions.microphone == .granted ? nil : "Request",
            action: model.requestMicrophonePermission
        )

        PermissionRow(
            title: "Speech Recognition",
            state: model.permissions.speech,
            detail: "Needed for Apple local speech recognition.",
            actionTitle: model.permissions.speech == .granted ? nil : "Request",
            action: model.requestSpeechPermission
        )

        PermissionRow(
            title: "Accessibility",
            state: model.permissions.accessibility,
            detail: "Only needed for automatic Cmd+V insertion.",
            actionTitle: model.permissions.accessibility == .granted ? nil : "Open Settings",
            action: model.requestAccessibility
        )
    }
}

private struct PermissionRow: View {
    var title: String
    var state: PermissionState
    var detail: String
    var actionTitle: String?
    var action: () -> Void

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(state.tint)
                        .frame(width: 8, height: 8)
                    Text(state.title)
                        .foregroundStyle(state.tint)
                }

                if let actionTitle {
                    Button(actionTitle, action: action)
                        .controlSize(.small)
                        .buttonStyle(NeutralPermissionButtonStyle())
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct NeutralPermissionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.13 : 0.08))
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}
