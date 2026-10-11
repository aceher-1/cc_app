import SwiftUI

enum CommonsTheme {
    static let red = Color(red: 0.77, green: 0.02, blue: 0.16)
    static let black = Color(red: 0.075, green: 0.075, blue: 0.085)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}

struct DietBadge: View {
    let title: String
    var body: some View {
        Text(title).font(.caption.weight(.medium))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .foregroundStyle(.primary)
            .background(CommonsTheme.red.opacity(0.09), in: Capsule())
    }
}

struct EmptyMenuView: View {
    let symbol: String
    let title: String
    let detail: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 36)).foregroundStyle(CommonsTheme.red).accessibilityHidden(true)
            Text(title).font(.title3.bold())
            Text(detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 24)
    }
}
