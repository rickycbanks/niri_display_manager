pragma Singleton
import QtQuick

QtObject {
    // Background layers (Noctalia defaults — not overridden by host theme)
    readonly property color bg:         "#12111a"
    readonly property color bgPanel:    "#1a1926"
    readonly property color bgCard:     "#211f30"
    readonly property color bgHover:    "#2a2840"

    // Borders
    readonly property color border:     "#2e2b45"
    readonly property color borderFocus: accent

    // Accent / primary — inherits from host via ThemeDyn, falls back to Noctalia lavender
    readonly property color accent:     (typeof ThemeDyn !== "undefined" && ThemeDyn.available)
                                            ? ThemeDyn.accent     : "#7c6af0"
    readonly property color accentDim:  (typeof ThemeDyn !== "undefined" && ThemeDyn.available)
                                            ? ThemeDyn.accentDim  : "#5b4cc4"
    readonly property color accentGlow: (typeof ThemeDyn !== "undefined" && ThemeDyn.available)
                                            ? ThemeDyn.accentGlow : "#9d8ff5"

    // Text
    readonly property color textPrimary:   "#e8e6f5"
    readonly property color textSecondary: "#9490b8"
    readonly property color textDisabled:  "#5a5778"
    readonly property color textOnAccent:  "#ffffff"

    // Status colors
    readonly property color success: "#6ac96a"
    readonly property color warning: "#e0a84a"
    readonly property color error:   "#e06464"

    // Monitor canvas
    readonly property color monitorActive:         "#2a2840"
    readonly property color monitorSelected:       Qt.rgba(accent.r, accent.g, accent.b, 0.25)
    readonly property color monitorDisabled:       "#1a1926"
    readonly property color monitorBorder:         "#4a4570"
    readonly property color monitorBorderSelected: accent

    // Spacing
    readonly property int spacingXS: 4
    readonly property int spacingS:  8
    readonly property int spacingM:  12
    readonly property int spacingL:  16
    readonly property int spacingXL: 24

    // Radii
    readonly property int radiusS: 4
    readonly property int radiusM: 8
    readonly property int radiusL: 12

    // Typography
    readonly property int fontSizeXS: 10
    readonly property int fontSizeS:  12
    readonly property int fontSizeM:  14
    readonly property int fontSizeL:  16
    readonly property int fontSizeXL: 20
    readonly property int fontSizeH:  26
}
