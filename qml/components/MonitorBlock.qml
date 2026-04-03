import QtQuick
import QtQuick.Controls
import "../theme"

Item {
    id: root

    required property var outputData
    required property bool selected
    required property real fitScale
    required property real offsetX
    required property real offsetY

    signal clicked()
    signal moved(string name, int newX, int newY)

    property real dragStartMouseX: 0
    property real dragStartMouseY: 0
    property int  dragStartPosX: 0
    property int  dragStartPosY: 0
    property bool isDragging: false

    // Position and size on canvas
    x: outputData.pos_x * fitScale + offsetX
    y: outputData.pos_y * fitScale + offsetY
    width: outputData.logical_width * fitScale
    height: outputData.logical_height * fitScale
    visible: outputData.enabled

    // Drop shadow
    Rectangle {
        anchors { fill: parent; topMargin: 3; leftMargin: 3 }
        color: "transparent"
        radius: Theme.radiusM
        layer.enabled: true
        layer.effect: null   // Placeholder for drop shadow
        opacity: 0.3
        Rectangle { anchors.fill: parent; color: "#000000"; radius: Theme.radiusM }
    }

    Rectangle {
        id: body
        anchors.fill: parent
        radius: Theme.radiusM
        color: {
            if (!outputData.enabled) return Theme.monitorDisabled
            if (root.selected) return Theme.monitorSelected
            return Theme.monitorActive
        }
        border.color: root.selected ? Theme.monitorBorderSelected : Theme.monitorBorder
        border.width: root.selected ? 2 : 1

        // Monitor name label
        Column {
            anchors.centerIn: parent
            spacing: 4

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: outputData.name
                color: Theme.textPrimary
                font.pixelSize: Math.max(10, Math.min(16, root.height * 0.18))
                font.weight: Font.Medium
                elide: Text.ElideRight
                width: body.width - 12
                horizontalAlignment: Text.AlignHCenter
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: {
                    var modes = outputData.modes
                    var idx = outputData.current_mode
                    if (idx !== null && idx !== undefined && idx >= 0 && idx < modes.length) {
                        var m = modes[idx]
                        return m.width + "×" + m.height
                    }
                    return ""
                }
                color: Theme.textSecondary
                font.pixelSize: Math.max(8, Math.min(11, root.height * 0.13))
                visible: root.height > 40
                elide: Text.ElideRight
                width: body.width - 12
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Disabled overlay
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusM
            color: Qt.rgba(0, 0, 0, 0.45)
            visible: !outputData.enabled
            Text {
                anchors.centerIn: parent
                text: "Off"
                color: Theme.textSecondary
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: function(mouse) {
                root.clicked()
                root.isDragging = false
                root.dragStartMouseX = mouse.x + root.x
                root.dragStartMouseY = mouse.y + root.y
                root.dragStartPosX = outputData.pos_x
                root.dragStartPosY = outputData.pos_y
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return
                root.isDragging = true
                var globalX = mouse.x + root.x
                var globalY = mouse.y + root.y
                var dx = (globalX - root.dragStartMouseX) / root.fitScale
                var dy = (globalY - root.dragStartMouseY) / root.fitScale
                var newX = Math.round(root.dragStartPosX + dx)
                var newY = Math.round(root.dragStartPosY + dy)
                root.moved(outputData.name, newX, newY)
            }

            onReleased: {
                root.isDragging = false
            }
        }
    }
}
