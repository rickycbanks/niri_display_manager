import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 900
    height: 620
    minimumWidth: 720
    minimumHeight: 520
    title: "Niri Display Manager"

    Rectangle {
        anchors.fill: parent
        color: "#1a1a2e"

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 16

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Niri Display Manager"
                font.pixelSize: 28
                font.weight: Font.Light
                color: "#c0a8ff"
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "Loading…"
                font.pixelSize: 14
                color: "#8888aa"
            }
        }
    }
}
