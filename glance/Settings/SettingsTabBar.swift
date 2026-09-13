//
//  SettingsTabBar.swift
//  glance
//
//  Floating pill tab bar pinned to the bottom of the Settings window. The
//  selected tab sits on its own highlight pill, which slides between tabs
//  and widens to show that tab's title.
//

import SwiftUI

struct SettingsTabBar: View {
    @Binding var selection: SettingsTab
    /// Whether the Face Lab tab should render — see
    /// `AppEnvironment.isDebugSectionRevealed`. This view only reflects it.
    let isDebugSectionRevealed: Bool

    @Namespace private var highlightNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SettingsTab.visibleTabs(includingDebug: isDebugSectionRevealed)) { tab in
                item(tab)
            }
        }
        .padding(.horizontal, SettingsMetrics.tabBarHorizontalPadding)
        .frame(height: SettingsMetrics.tabBarHeight)
        .background {
            // Within-window blending, unlike the window's own behind-window
            // material, so the bar blurs the page scrolling underneath it.
            VisualEffectView(
                blendingMode: .withinWindow,
                cornerRadius: SettingsMetrics.tabBarHeight / 2
            )
            Capsule()
                .fill(SettingsMetrics.tabBarTint)
        }
        .overlay(
            Capsule()
                .strokeBorder(SettingsMetrics.tabBarBorder, lineWidth: 1)
        )
        // Scoped here rather than `withAnimation` at the call site, so only
        // the bar animates — the page itself swaps instantly.
        .animation(SettingsMetrics.tabSelectionAnimation, value: selection)
    }

    private func item(_ tab: SettingsTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            HStack(spacing: 7) {
                SettingsTabGlyph(icon: tab.icon)
                if isSelected {
                    Text(tab.title)
                        .font(SettingsMetrics.tabTitleFont)
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.opacity)
                }
            }
            .foregroundStyle(SettingsMetrics.textPrimary)
            .padding(.horizontal, isSelected
                ? SettingsMetrics.selectedTabItemHorizontalPadding
                : SettingsMetrics.tabItemHorizontalPadding)
            .frame(height: SettingsMetrics.tabItemHeight)
            .background {
                if isSelected {
                    Capsule()
                        .fill(SettingsMetrics.selectedPillColor)
                        .matchedGeometryEffect(id: "highlight", in: highlightNamespace)
                }
            }
            // Without this, only the rendered glyph is hit-testable.
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
