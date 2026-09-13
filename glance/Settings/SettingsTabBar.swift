//
//  SettingsTabBar.swift
//  glance
//
//  Floating pill tab bar pinned to the bottom of the Settings window. The
//  selected tab sits on its own highlight pill, which slides between tabs
//  and widens to show that tab's title.
//

import SwiftUI

/// Each tab item's rendered frame, in the bar's own coordinate space — used
/// to position the single highlight pill without relying on
/// `matchedGeometryEffect`, which pops rather than slides when the view
/// carrying the id is torn down and rebuilt on a different button in the
/// same transaction (exactly what happens here every time selection changes).
private struct TabFramePreferenceKey: PreferenceKey {
    static var defaultValue: [SettingsTab: CGRect] = [:]
    static func reduce(value: inout [SettingsTab: CGRect], nextValue: () -> [SettingsTab: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct SettingsTabBar: View {
    @Binding var selection: SettingsTab
    /// Whether the Face Lab tab should render — see
    /// `AppEnvironment.isDebugSectionRevealed`. This view only reflects it.
    let isDebugSectionRevealed: Bool

    /// Every visible tab's measured frame, keyed by tab — read back via
    /// `TabFramePreferenceKey` from each item's own `GeometryReader`.
    @State private var tabFrames: [SettingsTab: CGRect] = [:]

    private static let coordinateSpace = "SettingsTabBar"

    var body: some View {
        ZStack(alignment: .topLeading) {
            // One pill, moved and resized to the selected tab's measured
            // frame — never removed/reinserted, so it always slides rather
            // than popping to the new tab.
            if let frame = tabFrames[selection] {
                Capsule()
                    .fill(SettingsMetrics.selectedPillColor)
                    .frame(width: frame.width, height: frame.height)
                    .offset(x: frame.minX, y: frame.minY)
                    .transition(.opacity)
            }

            HStack(spacing: 0) {
                ForEach(SettingsTab.visibleTabs(includingDebug: isDebugSectionRevealed)) { tab in
                    item(tab)
                }
            }
        }
        .coordinateSpace(name: Self.coordinateSpace)
        .padding(.horizontal, SettingsMetrics.tabBarHorizontalPadding)
        .frame(height: SettingsMetrics.tabBarHeight)
        .background {
            // SwiftUI's own material — a real, layered frosted-glass blur of
            // whatever scrolls underneath, unlike the flat/grey result the
            // within-window `NSVisualEffectView` gave here.
            Capsule()
                .fill(.regularMaterial)
            Capsule()
                .fill(SettingsMetrics.tabBarTint)
        }
        .overlay(
            Capsule()
                .strokeBorder(SettingsMetrics.tabBarBorder, lineWidth: 1)
        )
        .onPreferenceChange(TabFramePreferenceKey.self) { frames in
            withAnimation(SettingsMetrics.tabSelectionAnimation) {
                tabFrames = frames
            }
        }
    }

    private func item(_ tab: SettingsTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(SettingsMetrics.tabSelectionAnimation) {
                selection = tab
            }
        } label: {
            HStack(spacing: 7) {
                SettingsTabGlyph(icon: tab.icon)
                if isSelected {
                    Text(tab.title)
                        .font(SettingsMetrics.tabTitleFont)
                        .lineLimit(1)
                        .fixedSize()
                        // Outgoing: slides left into the icon, fading and
                        // blurring away. Incoming: starts from that same
                        // position (as if unfurling from the icon) and
                        // slides right into place while sharpening in.
                        .transition(.tabLabelReveal)
                }
            }
            .foregroundStyle(SettingsMetrics.textPrimary)
            .padding(.horizontal, isSelected
                ? SettingsMetrics.selectedTabItemHorizontalPadding
                : SettingsMetrics.tabItemHorizontalPadding)
            .frame(height: SettingsMetrics.tabItemHeight)
            // Without this, only the rendered glyph is hit-testable.
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TabFramePreferenceKey.self,
                    value: [tab: proxy.frame(in: .named(Self.coordinateSpace))]
                )
            }
        )
        .help(tab.title)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A tab's bare glyph — an SF Symbol or template asset, no badge behind it.
private struct SettingsTabGlyph: View {
    let icon: SettingsTabIcon

    var body: some View {
        Group {
            switch icon {
            case .system(let name):
                Image(systemName: name)
                    .font(.system(size: SettingsMetrics.tabGlyphSize, weight: .medium))
            case .asset(let name):
                // Marked `template-rendering-intent: template`, so AppKit fills
                // it from `.foregroundStyle` using the source art's alpha as a mask.
                Image(name)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: SettingsMetrics.tabGlyphSize - 1, height: SettingsMetrics.tabGlyphSize - 1)
            }
        }
        // Fixed box so glyphs of different widths space evenly along the bar.
        .frame(width: SettingsMetrics.tabGlyphSize + 4, height: SettingsMetrics.tabGlyphSize + 4)
    }
}

/// A tab label's entrance/exit: it reads as unfurling from, and collapsing
/// back into, the icon beside it — sliding along that edge while fading and
/// blurring, rather than a plain crossfade in place.
private struct TabLabelRevealModifier: ViewModifier {
    /// 1 = fully shown (identity); 0 = collapsed into the icon (active).
    var progress: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * SettingsMetrics.tabLabelRevealBlur)
            .offset(x: (1 - progress) * -SettingsMetrics.tabLabelRevealOffset)
    }
}

private extension AnyTransition {
    /// One modifier transition (not `.asymmetric`) so insertion runs
    /// active→identity and removal runs identity→active automatically —
    /// exactly the symmetric slide-toward-the-icon motion wanted here.
    static var tabLabelReveal: AnyTransition {
        .modifier(
            active: TabLabelRevealModifier(progress: 0),
            identity: TabLabelRevealModifier(progress: 1)
        )
    }
}
