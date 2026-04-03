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

    // ── Drag state ────────────────────────────────────────────────
    property bool isDragging: false
    property real _dragDx: 0       // accumulated screen-space drag offset X
    property real _dragDy: 0       // accumulated screen-space drag offset Y
    property real _anchorSceneX: 0 // scene X of mouse at drag start
    property real _anchorSceneY: 0 // scene Y of mouse at drag start
    property int  _originLogX: 0   // logical pos_x at drag start
    property int  _originLogY: 0   // logical pos_y at drag start

    // ── Position and size ─────────────────────────────────────────
    // During drag: shift visually by screen-space delta (don't touch outputData)
    // On release: emit moved() once with final logical coords
    x: outputData.pos_x * fitScale + offsetX + (isDragging ? _dragDx : 0)
    y: outputData.pos_y * fitScale + offsetY + (isDragging ? _dragDy : 0)
    width:  outputData.logical_width  * fitScale
    height: outputData.logical_height * fitScale
    // Always visible — disabled monitors show faded so they can be re-enabled
    visible: true
    opacity: outputData.enabled ? 1.0 : 0.45

    // ── Drop shadow ───────────────────────────────────────────────
    Rectangle {
        anchors { fill: parent; topMargin: 3; leftMargin: 3 }
        radius: Theme.radiusM
        color: "#000000"
        opacity: isDragging ? 0.4 : 0.2
    }

    // ── Body ──────────────────────────────────────────────────────
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

        // Drag indicator
        opacity: isDragging ? 0.85 : 1.0

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

        // Disabled overlay — no MouseArea, so clicks pass through to the body's MouseArea
        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusM
            color: Qt.rgba(0, 0, 0, 0.45)
            visible: !outputData.enabled
            Text { anchors.centerIn: parent; text: "Off"; color: Theme.textSecondary; font.pixelSize: 12 }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: root.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

            onPressed: function(mouse) {
                root.clicked()
                // Map press position to scene coords as stable drag anchor
                var scene = mapToItem(null, mouse.x, mouse.y)
                root._anchorSceneX = scene.x
                root._anchorSceneY = scene.y
                root._originLogX = outputData.pos_x
                root._originLogY = outputData.pos_y
                root._dragDx = 0
                root._dragDy = 0
                root.isDragging = false  // set true only on actual movement
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return
                var scene = mapToItem(null, mouse.x, mouse.y)
                var dxScreen = scene.x - root._anchorSceneX
                var dyScreen = scene.y - root._anchorSceneY
                // Only start dragging after moving a few pixels
                if (!root.isDragging && Math.abs(dxScreen) < 4 && Math.abs(dyScreen) < 4) return
                root.isDragging = true
                root._dragDx = dxScreen
                root._dragDy = dyScreen
            }

            onReleased: function(mouse) {
                if (root.isDragging) {
                    // Convert final screen offset to logical coordinates
                    var newX = root._originLogX + Math.round(root._dragDx / root.fitScale)
                    var newY = root._originLogY + Math.round(root._dragDy / root.fitScale)
                    root.moved(outputData.name, newX, newY)
                }
                root.isDragging = false
                root._dragDx = 0
                root._dragDy = 0
            }
        }
    }
}
