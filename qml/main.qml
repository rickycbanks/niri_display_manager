import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./theme"
import "./components"

ApplicationWindow {
    id: root
    visible: true
    width: 980
    height: 680
    minimumWidth: 760
    minimumHeight: 540
    title: "Niri Display Manager"
    color: Theme.bg

    // Error toast
    Popup {
        id: errorToast
        x: (parent.width - width) / 2
        y: parent.height - height - 16
        width: Math.min(errorText.implicitWidth + 32, parent.width - 48)
        height: errorText.implicitHeight + 24
        visible: DisplayBridge.errorMessage !== ""
        background: Rectangle { color: Theme.error; radius: Theme.radiusM }
        Text {
            id: errorText
            anchors.centerIn: parent
            text: DisplayBridge.errorMessage
            color: "#ffffff"
            font.pixelSize: Theme.fontSizeM
            wrapMode: Text.WordWrap
            width: parent.width - 32
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: Theme.spacingL }
        spacing: Theme.spacingM

        // ── Header ──────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Niri Display Manager"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeXL
                font.weight: Font.Light
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "↺ Refresh"
                flat: true
                onClicked: DisplayBridge.refresh()
                contentItem: Text {
                    text: parent.text; color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeS
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? Theme.bgHover : "transparent"
                    radius: Theme.radiusS
                }
            }
        }

        // ── Display Type Bar ─────────────────────────────────────────
        DisplayTypeBar {
            Layout.fillWidth: true
            selectedOutput: monitorCanvas.selectedOutput
        }

        // ── Main area: canvas + settings ────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.spacingM

            MonitorCanvas {
                id: monitorCanvas
                Layout.fillWidth: true
                Layout.fillHeight: true
                onOutputSelected: function(name) {
                    settingsPanel.outputName = name
                    settingsPanel.outputData = DisplayBridge.outputs.find(
                        function(o) { return o.name === name }
                    ) || null
                }
            }

            MonitorSettings {
                id: settingsPanel
                width: 280
                Layout.fillHeight: true
            }
        }

        // ── Preview banner ───────────────────────────────────────────
        PreviewBanner {
            id: previewBanner
            Layout.fillWidth: true
            visible: DisplayBridge.previewActive
            onKeep: DisplayBridge.keepPreview()
            onRevert: DisplayBridge.revertPreview()
        }

        // ── Footer: action buttons ───────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            // Profiles button (placeholder for Phase 7)
            Button {
                text: "Profiles"
                flat: true
                contentItem: Text {
                    text: parent.text; color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeM
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered ? Theme.bgHover : "transparent"
                    radius: Theme.radiusS; border.color: Theme.border; border.width: 1
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Preview"
                enabled: DisplayBridge.hasChanges && !DisplayBridge.previewActive
                onClicked: DisplayBridge.previewChanges()
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? Theme.textPrimary : Theme.textDisabled
                    font.pixelSize: Theme.fontSizeM
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered && parent.enabled ? Theme.bgHover : "transparent"
                    radius: Theme.radiusS; border.color: Theme.border; border.width: 1
                }
            }

            Button {
                text: "Revert"
                enabled: DisplayBridge.hasChanges
                onClicked: DisplayBridge.revertChanges()
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? Theme.textSecondary : Theme.textDisabled
                    font.pixelSize: Theme.fontSizeM
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.hovered && parent.enabled ? Theme.bgHover : "transparent"
                    radius: Theme.radiusS
                }
            }

            Button {
                id: applyBtn
                text: "Apply"
                enabled: DisplayBridge.hasChanges && !DisplayBridge.previewActive
                onClicked: DisplayBridge.applyChanges()
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? Theme.textOnAccent : Theme.textDisabled
                    font.pixelSize: Theme.fontSizeM
                    font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: applyBtn.enabled ? (applyBtn.hovered ? Theme.accentGlow : Theme.accent) : Theme.bgCard
                    radius: Theme.radiusS
                }
                leftPadding: 20; rightPadding: 20
            }
        }
    }
}
