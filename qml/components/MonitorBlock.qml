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
    property bool snapToGrid: false
    property int  gridSize:   10
    // Called with (name, logicalX, logicalY) during a drag; returns {x, y}
    // after edge-snapping against the other monitors. Set by MonitorCanvas.
    property var snapResolver: null

    signal clicked()
    signal moved(string name, int newX, int newY)
    signal dragFinished()

    // ── Drag state ────────────────────────────────────────────────
    property bool isDragging: false
    property real _anchorSceneX: 0 // scene X of mouse at drag start
    property real _anchorSceneY: 0 // scene Y of mouse at drag start
    property int  _originLogX: 0   // logical pos_x at drag start
    property int  _originLogY: 0   // logical pos_y at drag start
    property int  _dragLogX: 0     // snapped logical position under the cursor
    property int  _dragLogY: 0

    // ── Position and size ─────────────────────────────────────────
    // During drag: follow the snapped logical position (don't touch outputData)
    // On release: emit moved() once with final logical coords
    x: (isDragging ? _dragLogX : outputData.pos_x) * fitScale + offsetX
    y: (isDragging ? _dragLogY : outputData.pos_y) * fitScale + offsetY
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
            // Allow the parent Flickable to detect swipe gestures over monitor blocks.
            // When an intentional drag is detected (see onPositionChanged), we set
            // preventStealing=true so the Flickable can't reclaim the gesture.
            preventStealing: false

            onPressed: function(mouse) {
                root.clicked()
                var scene = mapToItem(null, mouse.x, mouse.y)
                root._anchorSceneX = scene.x
                root._anchorSceneY = scene.y
                root._originLogX = outputData.pos_x
                root._originLogY = outputData.pos_y
                root._dragLogX = outputData.pos_x
                root._dragLogY = outputData.pos_y
                root.isDragging = false
            }

            onPositionChanged: function(mouse) {
                if (!pressed) return
                var scene = mapToItem(null, mouse.x, mouse.y)
                var dxScreen = scene.x - root._anchorSceneX
                var dyScreen = scene.y - root._anchorSceneY
                if (!root.isDragging && Math.abs(dxScreen) < 4 && Math.abs(dyScreen) < 4) return
                if (!root.isDragging) {
                    // Lock the Flickable out so it doesn't scroll while we drag
                    mouseArea.preventStealing = true
                }
                root.isDragging = true

                var rawX = root._originLogX + dxScreen / root.fitScale
                var rawY = root._originLogY + dyScreen / root.fitScale
                if (root.snapToGrid) {
                    rawX = Math.round(rawX / root.gridSize) * root.gridSize
                    rawY = Math.round(rawY / root.gridSize) * root.gridSize
                }
                // Monitor-edge snapping wins over the grid: it is the placement
                // the user actually cares about (no gaps, no overlaps).
                var snapped = root.snapResolver
                    ? root.snapResolver(outputData.name, rawX, rawY)
                    : { x: rawX, y: rawY }
                root._dragLogX = Math.round(snapped.x)
                root._dragLogY = Math.round(snapped.y)
            }

            onReleased: function(mouse) {
                mouseArea.preventStealing = false
                if (root.isDragging) {
                    root.moved(outputData.name, root._dragLogX, root._dragLogY)
                }
                root.isDragging = false
                root.dragFinished()
            }

            onCanceled: {
                mouseArea.preventStealing = false
                root.isDragging = false
                root.dragFinished()
            }
        }
    }
}
