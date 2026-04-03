import QtQuick
import QtQuick.Controls
import "../theme"

Item {
    id: root

    property string selectedOutput: ""
    property bool snapToGrid: false
    property int  gridSize:   100   // logical pixels per snap step

    readonly property int padding: 40

    signal outputSelected(string name)

    // ── Bounds of all outputs ──────────────────────────────────────
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

    property real _fitScale: {
        var usableW = width  - padding * 2
        var usableH = height - padding * 2
        if (_bounds.w <= 0 || _bounds.h <= 0) return 0.1
        var sx = usableW / _bounds.w
        var sy = usableH / _bounds.h
        return Math.min(sx, sy, 0.25)
    }

    property real _contentW: Math.max(width  * 2.5, _bounds.w * _fitScale + padding * 8)
    property real _contentH: Math.max(height * 2.5, _bounds.h * _fitScale + padding * 8)
    property real _offsetX: (_contentW - _bounds.w * _fitScale) / 2 - _bounds.minX * _fitScale
    property real _offsetY: (_contentH - _bounds.h * _fitScale) / 2 - _bounds.minY * _fitScale

    // ── Background (fixed — not scrolled) ─────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Theme.bgCard
        radius: Theme.radiusL
        clip: true

        Canvas {
            id: bgCanvas
            anchors.fill: parent

            // Repaint when snap mode toggles
            property bool _snap: root.snapToGrid
            on_SnapChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var step = 24

                if (root.snapToGrid) {
                    // Grid lines — clearly shows snap mode is active
                    ctx.strokeStyle = Qt.rgba(
                        parseFloat(Theme.border.toString().slice(1,3), 16) / 255,
                        parseFloat(Theme.border.toString().slice(3,5), 16) / 255,
                        parseFloat(Theme.border.toString().slice(5,7), 16) / 255,
                        0.55)
                    // Simpler: use a semi-transparent border colour
                    ctx.strokeStyle = Theme.border
                    ctx.globalAlpha = 0.35
                    ctx.lineWidth = 0.5
                    ctx.beginPath()
                    for (var x = step; x < width; x += step) {
                        ctx.moveTo(x, 0)
                        ctx.lineTo(x, height)
                    }
                    for (var y = step; y < height; y += step) {
                        ctx.moveTo(0, y)
                        ctx.lineTo(width, y)
                    }
                    ctx.stroke()
                    ctx.globalAlpha = 1.0
                } else {
                    // Dot pattern — freeform mode
                    ctx.fillStyle = Theme.border
                    for (var dx = step; dx < width; dx += step) {
                        for (var dy = step; dy < height; dy += step) {
                            ctx.beginPath()
                            ctx.arc(dx, dy, 1, 0, Math.PI * 2)
                            ctx.fill()
                        }
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

        // Always interactive — MonitorBlock MouseAreas use preventStealing
        // to take over when an intentional drag is detected.
        interactive: true

        flickDeceleration: 1500
        maximumFlickVelocity: 2500

        function centerOnMonitors() {
            var cx = (_contentW - width)  / 2
            var cy = (_contentH - height) / 2
            contentX = Math.max(0, cx)
            contentY = Math.max(0, cy)
        }

        onContentWidthChanged:  Qt.callLater(centerOnMonitors)
        onContentHeightChanged: Qt.callLater(centerOnMonitors)

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
                        root.forceActiveFocus()
                    }
                    onMoved: function(name, nx, ny) {
                        DisplayBridge.setPosition(name, nx, ny)
                    }
                }
            }
        }
    }

    // ── Keyboard: arrow keys move selected monitor, Esc deselects ──
    focus: true
    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            root.selectedOutput = ""
            event.accepted = true
            return
        }
        if (root.selectedOutput === "") return
        var step = root.snapToGrid ? root.gridSize : 1
        var dx = 0, dy = 0
        switch (event.key) {
            case Qt.Key_Left:  dx = -step; break
            case Qt.Key_Right: dx =  step; break
            case Qt.Key_Up:    dy = -step; break
            case Qt.Key_Down:  dy =  step; break
            default: return
        }
        var outs = DisplayBridge.outputs
        for (var i = 0; i < outs.length; i++) {
            if (outs[i].name === root.selectedOutput) {
                DisplayBridge.setPosition(outs[i].name, outs[i].pos_x + dx, outs[i].pos_y + dy)
                event.accepted = true
                return
            }
        }
    }

    // ── Scroll-position hints ──────────────────────────────────────
    Item {
        anchors.fill: parent
        Rectangle {
            visible: flickable.contentX > 1
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 20; height: 48; radius: 4; color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "‹"; color: Theme.textSecondary; font.pixelSize: 18 }
        }
        Rectangle {
            visible: flickable.contentX < flickable.contentWidth - flickable.width - 1
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 20; height: 48; radius: 4; color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "›"; color: Theme.textSecondary; font.pixelSize: 18 }
        }
        Rectangle {
            visible: flickable.contentY > 1
            anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
            width: 48; height: 20; radius: 4; color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "⌃"; color: Theme.textSecondary; font.pixelSize: 14 }
        }
        Rectangle {
            visible: flickable.contentY < flickable.contentHeight - flickable.height - 1
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter }
            width: 48; height: 20; radius: 4; color: Qt.rgba(0,0,0,0.18)
            Text { anchors.centerIn: parent; text: "⌄"; color: Theme.textSecondary; font.pixelSize: 14 }
        }
    }
}
