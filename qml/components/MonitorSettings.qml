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

        // ── Header ───────────────────────────────────────────────────
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

            Switch {
                checked: outputData ? outputData.enabled : false
                onToggled: DisplayBridge.setEnabled(outputName, checked)
                palette.button: Theme.accentDim
                palette.highlight: Theme.accent
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

        // ── Resolution ───────────────────────────────────────────────
        SectionLabel { text: "Resolution" }
        ComboBox {
            id: resCombo
            Layout.fillWidth: true
            enabled: outputData && outputData.enabled

            // Build unique sorted resolution list from available modes
            model: {
                if (!outputData) return []
                var seen = {}
                var res = []
                var modes = outputData.modes
                for (var i = 0; i < modes.length; i++) {
                    var key = modes[i].width + "x" + modes[i].height
                    if (!seen[key]) {
                        seen[key] = true
                        res.push(key)
                    }
                }
                // Sort descending by pixel count
                res.sort(function(a, b) {
                    var pa = a.split("x"), pb = b.split("x")
                    return (parseInt(pb[0]) * parseInt(pb[1])) - (parseInt(pa[0]) * parseInt(pa[1]))
                })
                return res
            }

            currentIndex: {
                if (!outputData || !outputData.modes) return 0
                var mi = outputData.current_mode || 0
                var m = outputData.modes[mi]
                if (!m) return 0
                var key = m.width + "x" + m.height
                for (var i = 0; i < model.length; i++) {
                    if (model[i] === key) return i
                }
                return 0
            }

            onActivated: {
                // When resolution changes, select the first (highest refresh) mode for that res
                if (!outputData) return
                var chosen = model[currentIndex]
                var modes = outputData.modes
                var bestIdx = -1
                var bestHz = -1
                for (var i = 0; i < modes.length; i++) {
                    var key = modes[i].width + "x" + modes[i].height
                    if (key === chosen && modes[i].refresh_hz > bestHz) {
                        bestHz = modes[i].refresh_hz
                        bestIdx = i
                    }
                }
                if (bestIdx >= 0) DisplayBridge.setModeIndex(outputName, bestIdx)
            }

            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: resCombo.width
                contentItem: Text {
                    text: modelData
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeM
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.highlighted ? Theme.bgHover : Theme.bgCard
                }
            }
            background: Rectangle {
                color: Theme.bgCard; radius: Theme.radiusS
                border.color: resCombo.activeFocus ? Theme.borderFocus : Theme.border
            }
            contentItem: Text {
                leftPadding: Theme.spacingS
                text: resCombo.displayText
                color: resCombo.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSizeM
                verticalAlignment: Text.AlignVCenter
            }
            popup: Popup {
                y: resCombo.height + 2
                width: resCombo.width
                padding: 0
                contentItem: ListView {
                    implicitHeight: Math.min(contentHeight, 200)
                    model: resCombo.delegateModel
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
                background: Rectangle { color: Theme.bgCard; radius: Theme.radiusS; border.color: Theme.border }
            }
        }

        // ── Refresh Rate ─────────────────────────────────────────────
        SectionLabel { text: "Refresh Rate" }
        ComboBox {
            id: refreshCombo
            Layout.fillWidth: true
            enabled: outputData && outputData.enabled

            // Show refresh rates for the currently selected resolution
            property string selectedRes: resCombo.count > 0 ? resCombo.model[resCombo.currentIndex] ?? "" : ""

            model: {
                if (!outputData || !selectedRes) return []
                var rates = []
                var modes = outputData.modes
                for (var i = 0; i < modes.length; i++) {
                    var key = modes[i].width + "x" + modes[i].height
                    if (key === selectedRes) {
                        rates.push({ idx: i, hz: modes[i].refresh_hz, label: modes[i].refresh_hz.toFixed(3) + " Hz" + (modes[i].is_preferred ? " ★" : "") })
                    }
                }
                rates.sort(function(a, b) { return b.hz - a.hz })
                return rates
            }

            textRole: "label"

            currentIndex: {
                if (!outputData || !model || model.length === 0) return 0
                var mi = outputData.current_mode || 0
                for (var i = 0; i < model.length; i++) {
                    if (model[i].idx === mi) return i
                }
                return 0
            }

            onActivated: {
                if (model && currentIndex < model.length) {
                    DisplayBridge.setModeIndex(outputName, model[currentIndex].idx)
                }
            }

            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: refreshCombo.width
                contentItem: Text {
                    text: modelData.label
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeM
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.highlighted ? Theme.bgHover : Theme.bgCard
                }
            }
            background: Rectangle {
                color: Theme.bgCard; radius: Theme.radiusS
                border.color: refreshCombo.activeFocus ? Theme.borderFocus : Theme.border
            }
            contentItem: Text {
                leftPadding: Theme.spacingS
                text: refreshCombo.displayText
                color: refreshCombo.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSizeM
                verticalAlignment: Text.AlignVCenter
            }
            popup: Popup {
                y: refreshCombo.height + 2
                width: refreshCombo.width
                padding: 0
                contentItem: ListView {
                    implicitHeight: Math.min(contentHeight, 200)
                    model: refreshCombo.delegateModel
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
                background: Rectangle { color: Theme.bgCard; radius: Theme.radiusS; border.color: Theme.border }
            }
        }

        // ── Scale ────────────────────────────────────────────────────
        SectionLabel { text: "Scale" }
        ComboBox {
            id: scaleCombo
            Layout.fillWidth: true
            enabled: outputData && outputData.enabled

            // Common HiDPI scale values Niri supports
            readonly property var scaleValues: [0.5, 0.625, 0.75, 0.875, 1.0, 1.25, 1.5, 1.75, 2.0, 2.25, 2.5, 3.0]

            model: scaleValues.map(function(v) {
                return (v * 100).toFixed(0) + "%  (" + v.toFixed(2) + "×)"
            })

            currentIndex: {
                if (!outputData) return 4  // default 1.0
                var s = outputData.scale || 1.0
                for (var i = 0; i < scaleValues.length; i++) {
                    if (Math.abs(scaleValues[i] - s) < 0.01) return i
                }
                // Nearest
                var best = 4, diff = 999
                for (var j = 0; j < scaleValues.length; j++) {
                    var d = Math.abs(scaleValues[j] - s)
                    if (d < diff) { diff = d; best = j }
                }
                return best
            }

            onActivated: {
                DisplayBridge.setScale(outputName, scaleValues[currentIndex])
            }

            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: scaleCombo.width
                contentItem: Text {
                    text: modelData
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeM
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.highlighted ? Theme.bgHover : Theme.bgCard
                }
            }
            background: Rectangle {
                color: Theme.bgCard; radius: Theme.radiusS
                border.color: scaleCombo.activeFocus ? Theme.borderFocus : Theme.border
            }
            contentItem: Text {
                leftPadding: Theme.spacingS
                text: scaleCombo.displayText
                color: scaleCombo.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSizeM
                verticalAlignment: Text.AlignVCenter
            }
            popup: Popup {
                y: scaleCombo.height + 2
                width: scaleCombo.width
                padding: 0
                contentItem: ListView {
                    implicitHeight: Math.min(contentHeight, 240)
                    model: scaleCombo.delegateModel
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                }
                background: Rectangle { color: Theme.bgCard; radius: Theme.radiusS; border.color: Theme.border }
            }
        }

        // ── Rotation ─────────────────────────────────────────────────
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
            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: transformCombo.width
                contentItem: Text {
                    text: modelData.label
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeM
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: parent.highlighted ? Theme.bgHover : Theme.bgCard
                }
            }
            background: Rectangle {
                color: Theme.bgCard; radius: Theme.radiusS
                border.color: transformCombo.activeFocus ? Theme.borderFocus : Theme.border
            }
            contentItem: Text {
                leftPadding: Theme.spacingS
                text: transformCombo.displayText
                color: transformCombo.enabled ? Theme.textPrimary : Theme.textDisabled
                font.pixelSize: Theme.fontSizeM
                verticalAlignment: Text.AlignVCenter
            }
            popup: Popup {
                y: transformCombo.height + 2
                width: transformCombo.width
                padding: 0
                contentItem: ListView {
                    implicitHeight: Math.min(contentHeight, 200)
                    model: transformCombo.delegateModel
                    clip: true
                }
                background: Rectangle { color: Theme.bgCard; radius: Theme.radiusS; border.color: Theme.border }
            }
        }

        // ── VRR ──────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            visible: outputData && outputData.vrr_supported
            Text {
                text: "Variable Refresh Rate"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeM
                Layout.fillWidth: true
            }
            Switch {
                checked: outputData ? outputData.vrr_enabled : false
                enabled: outputData && outputData.enabled && outputData.vrr_supported
                onToggled: DisplayBridge.setVrr(outputName, checked)
            }
        }

        Item { Layout.fillHeight: true }
    }

    component SectionLabel: Text {
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeXS
        font.weight: Font.Medium
        text: ""
        Layout.fillWidth: true
    }
}
