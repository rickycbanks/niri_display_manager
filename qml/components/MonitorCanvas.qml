import QtQuick
import QtQuick.Controls
import "../theme"

Item {
    id: root

    property string selectedOutput: ""
    // Snap-to-grid: when true, released position is rounded to gridSize logical px
    property bool snapToGrid: false
    property int  gridSize:   10

    readonly property int padding: 40

    signal outputSelected(string name)

    // ── Bounds of all outputs (enabled + disabled) ─────────────────
    property var _bounds: {
        var minX = 0, minY = 0, maxX = 1, maxY = 1
        for (var i = 0; i < DisplayBridge.outputs.length; i++) {
            var o = DisplayBridge.outputs[i]
            minX = Math.min(minX, o.pos_x)
            minY = Math.min(minY, o.pos_y)
            maxX = Math.max(maxX, o.pos_x + o.logical_width)
            maxY = Math.max(maxY, o.pos_y + o.logical_height)
        }
        return { minX: minX, minY: minY, w: maxX - minX, h: maxY - minY }
    }

    // Scale to fit the current arrangement in the visible viewport
    property real _fitScale: {
        var usableW = width  - padding * 2
        var usableH = height - padding * 2
        if (_bounds.w <= 0 || _bounds.h <= 0) return 0.1
        var sx = usableW / _bounds.w
        var sy = usableH / _bounds.h
        return Math.min(sx, sy, 0.25)
    }

    // Content area — large enough to scroll around comfortably
    property real _contentW: Math.max(width  * 2.5, _bounds.w * _fitScale + padding * 8)
    property real _contentH: Math.max(height * 2.5, _bounds.h * _fitScale + padding * 8)

    // Offset so monitors are centred inside the content area
    property real _offsetX: (_contentW - _bounds.w * _fitScale) / 2 - _bounds.minX * _fitScale
    property real _offsetY: (_contentH - _bounds.h * _fitScale) / 2 - _bounds.minY * _fitScale

    // Track whether any block is currently being dragged (disables Flickable while dragging)
    property int _draggingCount: 0

    // ── Background (fixed, not scrolled) ───────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.bgCard
        radius: Theme.radiusL
        clip: true

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.fillStyle = Theme.border
                var step = 24
                for (var x = step; x < width; x += step) {
                    for (var y = step; y < height; y += step) {
                        ctx.beginPath()
                        ctx.arc(x, y, 1, 0, Math.PI * 2)
                        ctx.fill()
                    }
                }
            }
        }
    }

    // ── Scrollable / pannable viewport ─────────────────────────────
    Flickable {
        id: flickable
        anchors.fill: parent
        clip: true

        contentWidth:  root._contentW
        contentHeight: root._contentH

        // Disable flick while the user is dragging a monitor block
        interactive: root._draggingCount === 0

        // Smooth deceleration for panning feel
        flickDeceleration: 1500
        maximumFlickVelocity: 2500

        // Centre on the monitors when layout changes (e.g. on load or refresh)
        function centerOnMonitors() {
            var cx = (_contentW - width)  / 2
            var cy = (_contentH - height) / 2
            contentX = Math.max(0, cx)
            contentY = Math.max(0, cy)
        }

        onContentWidthChanged:  Qt.callLater(centerOnMonitors)
        onContentHeightChanged: Qt.callLater(centerOnMonitors)

        // Monitor blocks live inside the scrollable content item
        Item {
            width:  flickable.contentWidth
            height: flickable.contentHeight

            Repeater {
                model: DisplayBridge.outputs
                delegate: MonitorBlock {
                    required property var modelData
                    outputData: modelData
                    selected:   modelData.name === root.selectedOutput
                    fitScale:   root._fitScale
                    offsetX:    root._offsetX
                    offsetY:    root._offsetY
                    snapToGrid: root.snapToGrid
                    gridSize:   root.gridSize

                    onClicked: {
                        root.selectedOutput = outputData.name
                        root.outputSelected(outputData.name)
                    }
                    onMoved: function(name, nx, ny) {
                        DisplayBridge.setPosition(name, nx, ny)
                    }
                    onDragStarted: root._draggingCount++
                    onDragEnded:   root._draggingCount = Math.max(0, root._draggingCount - 1)
                }
            }
        }
    }

    // Scroll-position hint — faint arrows at edges when content is larger than viewport
    Item {
        anchors.fill: parent
        // Left hint
        Rectangle {
            visible: flickable.contentX > 0
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 20; height: 48; radius: 4
            color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "‹"; color: Theme.textSecondary; font.pixelSize: 18 }
        }
        // Right hint
        Rectangle {
            visible: flickable.contentX < flickable.contentWidth - flickable.width - 1
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 20; height: 48; radius: 4
            color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "›"; color: Theme.textSecondary; font.pixelSize: 18 }
        }
        // Top hint
        Rectangle {
            visible: flickable.contentY > 0
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: 48; height: 20; radius: 4
            color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "⌃"; color: Theme.textSecondary; font.pixelSize: 14 }
        }
        // Bottom hint
        Rectangle {
            visible: flickable.contentY < flickable.contentHeight - flickable.height - 1
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 48; height: 20; radius: 4
            color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "⌄"; color: Theme.textSecondary; font.pixelSize: 14 }
        }
    }
}
