import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Preview mode banner — shown during the 10-second countdown.
Rectangle {
    id: root
    visible: false
    height: 52
    radius: Theme.radiusM
    color: Qt.rgba(0.1, 0.08, 0.2, 0.97)
    border.color: Theme.warning
    border.width: 1

    signal keep()
    signal revert()

    RowLayout {
        anchors { fill: parent; margins: Theme.spacingM }
        spacing: Theme.spacingM

        Text {
            Layout.alignment: Qt.AlignVCenter
            text: "⏱  Reverting in " + DisplayBridge.previewSecondsLeft + "s — keep these settings?"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeM
        }

        Item { Layout.fillWidth: true }

        ActionButton {
            Layout.alignment: Qt.AlignVCenter
            label: "Keep"
            accent: true
            onClicked: root.keep()
        }
        ActionButton {
            Layout.alignment: Qt.AlignVCenter
            label: "Revert"
            onClicked: root.revert()
        }
    }

    component ActionButton: Rectangle {
        property string label: ""
        property bool accent: false
        signal clicked()
        width: lbl.implicitWidth + 24; height: 32
        radius: Theme.radiusS
        color: accent ? Theme.accent : Theme.bgCard
        border.color: accent ? Theme.accentGlow : Theme.border
        Text { id: lbl; anchors.centerIn: parent; text: parent.label; color: Theme.textOnAccent; font.pixelSize: Theme.fontSizeM }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.clicked() }
    }
}
