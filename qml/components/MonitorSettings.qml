import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root

    property string outputName: ""
    property var outputData: null

    color: Theme.bgPanel
    radius: Theme.radiusL

    // No output selected placeholder
    Item {
        anchors.centerIn: parent
        visible: !outputData
        Text {
            text: "Select a monitor"
            color: Theme.textDisabled
            font.pixelSize: Theme.fontSizeM
        }
    }

    ColumnLayout {
        anchors { fill: parent; margins: Theme.spacingL }
        spacing: Theme.spacingM
        visible: outputData !== null

        // Header
        RowLayout {
            Layout.fillWidth: true
            Column {
                Layout.fillWidth: true
                Text {
                    text: outputData ? outputData.displayName : ""
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeL
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    width: parent.width
                }
                Text {
                    text: outputData ? outputData.name : ""
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeS
                }
            }

            // Enable/Disable toggle
            Switch {
                checked: outputData ? outputData.enabled : false
                onToggled: DisplayBridge.setEnabled(outputName, checked)
                palette.button: Theme.accentDim
                palette.highlight: Theme.accent
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // Resolution + Refresh Rate
        SectionLabel { text: "Resolution & Refresh Rate" }

        ComboBox {
            id: modeCombo
            Layout.fillWidth: true
            enabled: outputData && outputData.enabled
            model: {
                if (!outputData) return []
                return outputData.modes.map(function(m) { return m.label })
            }
            currentIndex: outputData ? (outputData.current_mode || 0) : 0
            onActivated: function(idx) {
                DisplayBridge.setModeIndex(outputName, idx)
            }
            background: Rectangle {
                color: Theme.bgCard
                radius: Theme.radiusS
                border.color: modeCombo.activeFocus ? Theme.borderFocus : Theme.border
            }
            contentItem: Text {
                leftPadding: Theme.spacingS
                text: modeCombo.displayText
                color: modeCombo.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSizeM
                verticalAlignment: Text.AlignVCenter
            }
        }

        // Scale
        SectionLabel { text: "Scale" }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            Slider {
                id: scaleSlider
                Layout.fillWidth: true
                from: 0.5; to: 3.0; stepSize: 0.25
                enabled: outputData && outputData.enabled
                value: outputData ? outputData.scale : 1.0
                onMoved: DisplayBridge.setScale(outputName, value)
                background: Rectangle {
                    x: scaleSlider.leftPadding; y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                    width: scaleSlider.availableWidth; height: 4
                    radius: 2; color: Theme.border
                    Rectangle {
                        width: scaleSlider.visualPosition * parent.width
                        height: parent.height; radius: 2; color: Theme.accent
                    }
                }
                handle: Rectangle {
                    x: scaleSlider.leftPadding + scaleSlider.visualPosition * scaleSlider.availableWidth - width / 2
                    y: scaleSlider.topPadding + scaleSlider.availableHeight / 2 - height / 2
                    width: 16; height: 16; radius: 8
                    color: Theme.accent
                    border.color: Theme.accentGlow; border.width: 1
                }
            }
            Text {
                text: outputData ? outputData.scale.toFixed(2) + "×" : ""
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeM
                font.weight: Font.Medium
                width: 44
                horizontalAlignment: Text.AlignRight
            }
        }

        // Rotation/Transform
        SectionLabel { text: "Rotation" }
        ComboBox {
            id: transformCombo
            Layout.fillWidth: true
            enabled: outputData && outputData.enabled
            model: DisplayBridge.getTransformOptions()
            textRole: "label"
            valueRole: "value"
            currentIndex: {
                if (!outputData) return 0
                var t = outputData.transform || "Normal"
                var opts = DisplayBridge.getTransformOptions()
                for (var i = 0; i < opts.length; i++) {
                    if (opts[i].value === t) return i
                }
                return 0
            }
            onActivated: DisplayBridge.setTransform(outputName, currentValue)
            background: Rectangle {
                color: Theme.bgCard; radius: Theme.radiusS
                border.color: transformCombo.activeFocus ? Theme.borderFocus : Theme.border
            }
            contentItem: Text {
                leftPadding: Theme.spacingS
                text: transformCombo.displayText
                color: transformCombo.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSizeM; verticalAlignment: Text.AlignVCenter
            }
        }

        // VRR
        RowLayout {
            Layout.fillWidth: true
            visible: outputData && outputData.vrr_supported
            Text { text: "Variable Refresh Rate (VRR)"; color: Theme.textPrimary; font.pixelSize: Theme.fontSizeM; Layout.fillWidth: true }
            Switch {
                checked: outputData ? outputData.vrr_enabled : false
                enabled: outputData && outputData.enabled && outputData.vrr_supported
                onToggled: DisplayBridge.setVrr(outputName, checked)
            }
        }

        Item { Layout.fillHeight: true }
    }

    // Internal label component
    component SectionLabel: Text {
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeXS
        font.weight: Font.Medium
        text: ""
        Layout.fillWidth: true
    }
}
