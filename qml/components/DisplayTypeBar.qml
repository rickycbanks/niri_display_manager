import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

RowLayout {
    id: root
    spacing: Theme.spacingS

    property string selectedOutput: ""

    Text {
        text: "Display Mode:"
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeS
    }

    Repeater {
        model: [
            { value: "extend",   label: "Extend",  icon: "⬛⬜" },
            { value: "mirror",   label: "Mirror",  icon: "⬛⬛" },
            { value: "single",   label: "Single",  icon: "⬛"   },
        ]
        delegate: ModeButton {
            label: modelData.label
            icon: modelData.icon
            active: {
                if (!selectedOutput) return false
                var out = DisplayBridge.outputs.find(function(o) { return o.name === selectedOutput })
                return out ? (out.display_type === modelData.value) : false
            }
            onClicked: {
                if (selectedOutput)
                    DisplayBridge.setDisplayType(selectedOutput, modelData.value)
            }
        }
    }

    Item { Layout.fillWidth: true }

    // Identify button
    Button {
        text: "Identify Monitors"
        onClicked: {
            for (var i = 0; i < DisplayBridge.outputs.length; i++) {
                var o = DisplayBridge.outputs[i]
                if (o.enabled) {
                    var component = Qt.createComponent("MonitorIdOverlay.qml")
                    if (component.status === Component.Ready) {
                        component.createObject(null, {
                            outputName: o.name,
                            outputIndex: i + 1,
                            posX: o.pos_x,
                            posY: o.pos_y,
                            outWidth: o.logical_width,
                            outHeight: o.logical_height,
                        })
                    }
                }
            }
        }
        background: Rectangle {
            color: Theme.bgCard; radius: Theme.radiusS
            border.color: Theme.border; border.width: 1
        }
        contentItem: Text {
            text: parent.text; color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeS
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            leftPadding: 8; rightPadding: 8
        }
    }

    component ModeButton: Rectangle {
        property string label: ""
        property string icon: ""
        property bool active: false
        signal clicked()

        width: labelText.implicitWidth + 24
        height: 32
        radius: Theme.radiusS
        color: active ? Theme.accentDim : Theme.bgCard
        border.color: active ? Theme.accent : Theme.border
        border.width: 1

        Text {
            id: labelText
            anchors.centerIn: parent
            text: parent.label
            color: parent.active ? Theme.textOnAccent : Theme.textPrimary
            font.pixelSize: Theme.fontSizeS
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
