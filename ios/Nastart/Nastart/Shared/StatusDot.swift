import SwiftUI

struct StatusDot: View {
    let status: ServiceStatus

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .accessibilityLabel(accessibilityLabel)
    }

    private var color: Color {
        switch status {
        case .online: return .green
        case .installed: return .blue
        case .warning: return .orange
        case .offline: return .gray
        case .unknown: return .secondary
        }
    }

    private var accessibilityLabel: Text {
        switch status {
        case .online: return Text("status.online")
        case .installed: return Text("status.installed")
        case .warning: return Text("status.warning")
        case .offline: return Text("status.offline")
        case .unknown: return Text("status.unknown")
        }
    }
}
