import QtQuick
import QtQuick.Controls
import "../theme"

// Placeholder — profile management will be implemented in Phase 7.
Rectangle {
    id: root
    color: Theme.bgPanel
    radius: Theme.radiusL

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingS
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Profiles"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeM
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Coming in Phase 7"
            color: Theme.textDisabled
            font.pixelSize: Theme.fontSizeS
        }
    }
}
