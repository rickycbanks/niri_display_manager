import QtQuick
import QtQuick.Controls
import "../theme"

// Fullscreen overlay shown on a specific monitor to identify it.
// Closes automatically after 3 seconds.
Window {
    id: root

    required property string outputName
    required property int outputIndex
    required property int posX
    required property int posY
    required property int outWidth
    required property int outHeight

    flags: Qt.Window | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    visibility: Window.FullScreen
    x: posX; y: posY
    width: outWidth; height: outHeight
    visible: true
    color: "transparent"

    Timer {
        interval: 3000
        running: true
        onTriggered: root.close()
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.75)

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "" + root.outputIndex
                color: Theme.accent
                font.pixelSize: 140
                font.weight: Font.Bold
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.outputName
                color: Theme.textPrimary
                font.pixelSize: 28
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }
}
