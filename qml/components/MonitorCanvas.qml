import QtQuick
import QtQuick.Controls
import "../theme"

Item {
    id: root

    property string selectedOutput: ""
    property bool snapToGrid: false
    property int  gridSize:   100   // logical pixels per snap step

    // Snap a dragged monitor to its neighbours' edges (any side) and to their
    // edge/centre alignments. Threshold is in *screen* pixels so it feels the
    // same however far the canvas is zoomed out.
    property bool snapToMonitors: true
    readonly property int snapThresholdPx: 14

    readonly property int padding: 40

    signal outputSelected(string name)

    // ── Snap guides (logical coords; null when nothing is snapped) ──
    property var _guideX: null
    property var _guideY: null

    function _clearGuides() {
        root._guideX = null
        root._guideY = null
    }

    // Resolve a dragged logical position into a snapped one. Returns {x, y}
    // and publishes the guide lines that were hit as a side effect.
    function _resolveSnap(name, logX, logY) {
        if (!root.snapToMonitors) {
            root._clearGuides()
            return { x: logX, y: logY }
        }

        var outs = DisplayBridge.outputs
        var self = null
        for (var i = 0; i < outs.length; i++) {
            if (outs[i].name === name) { self = outs[i]; break }
        }
        if (!self) {
            root._clearGuides()
            return { x: logX, y: logY }
        }

        var w = self.logical_width
        var h = self.logical_height
        var tol = root.snapThresholdPx / Math.max(root._fitScale, 0.0001)

        // best = { delta, value, guide } — value is the snapped pos_x/pos_y,
        // guide is the logical coordinate of the line to draw.
        var bestX = null
        var bestY = null

        // candidate = the pos_x/pos_y the drag would snap to; guide = the
        // logical coordinate of the shared line, for the on-screen hint.
        function consider(best, candidate, current, guide) {
            var delta = Math.abs(candidate - current)
            if (delta > tol) return best
            if (best !== null && delta >= best.delta) return best
            return { delta: delta, value: candidate, guide: guide }
        }

        for (var j = 0; j < outs.length; j++) {
            var o = outs[j]
            if (o.name === name) continue
            var ox = o.pos_x, oy = o.pos_y
            var ow = o.logical_width, oh = o.logical_height

            // ── Horizontal: butt against the left/right sides, then align ──
            bestX = consider(bestX, ox + ow, logX, ox + ow)          // our left edge ↔ their right edge
            bestX = consider(bestX, ox - w,  logX, ox)               // our right edge ↔ their left edge
            bestX = consider(bestX, ox,      logX, ox)               // left edges aligned
            bestX = consider(bestX, ox + ow - w, logX, ox + ow)      // right edges aligned
            bestX = consider(bestX, ox + ow / 2 - w / 2, logX, ox + ow / 2)  // centres aligned

            // ── Vertical: butt against the top/bottom sides, then align ────
            bestY = consider(bestY, oy + oh, logY, oy + oh)          // our top edge ↔ their bottom edge
            bestY = consider(bestY, oy - h,  logY, oy)               // our bottom edge ↔ their top edge
            bestY = consider(bestY, oy,      logY, oy)               // top edges aligned
            bestY = consider(bestY, oy + oh - h, logY, oy + oh)      // bottom edges aligned
            bestY = consider(bestY, oy + oh / 2 - h / 2, logY, oy + oh / 2)  // centres aligned
        }

        root._guideX = bestX !== null ? bestX.guide : null
        root._guideY = bestY !== null ? bestY.guide : null

        return {
            x: bestX !== null ? bestX.value : logX,
            y: bestY !== null ? bestY.value : logY,
        }
    }

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

            Connections {
                target: root
                function onSnapToGridChanged() { bgCanvas.requestPaint() }
            }

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var step = 24

                if (root.snapToGrid) {
                    // Near-white lines for clear visibility against the dark canvas
                    ctx.strokeStyle = Qt.rgba(Theme.accentGlow.r, Theme.accentGlow.g, Theme.accentGlow.b, 0.4)
                    ctx.lineWidth = 1
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
                    // Solid near-white dots at intersections to mark snap points
                    ctx.fillStyle = Qt.rgba(Theme.accentGlow.r, Theme.accentGlow.g, Theme.accentGlow.b, 0.8)
                    for (var ix = step; ix < width; ix += step) {
                        for (var iy = step; iy < height; iy += step) {
                            ctx.beginPath()
                            ctx.arc(ix, iy, 1.5, 0, Math.PI * 2)
                            ctx.fill()
                        }
                    }
                } else {
                    // Dot pattern — freeform mode
                    ctx.fillStyle = Qt.rgba(Theme.textPrimary.r, Theme.textPrimary.g, Theme.textPrimary.b, 0.2)
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
                    snapResolver: root._resolveSnap

                    onClicked: {
                        root.selectedOutput = outputData.name
                        root.outputSelected(outputData.name)
                        root.forceActiveFocus()
                    }
                    onMoved: function(name, nx, ny) {
                        DisplayBridge.setPosition(name, nx, ny)
                    }
                    onDragFinished: root._clearGuides()
                }
            }

            // ── Snap guides — drawn above the blocks while dragging ────
            Rectangle {
                visible: root._guideX !== null
                x: (root._guideX !== null ? root._guideX * root._fitScale + root._offsetX : 0) - 1
                y: 0
                width: 2
                height: parent.height
                color: Theme.accent
                opacity: 0.85
            }
            Rectangle {
                visible: root._guideY !== null
                x: 0
                y: (root._guideY !== null ? root._guideY * root._fitScale + root._offsetY : 0) - 1
                width: parent.width
                height: 2
                color: Theme.accent
                opacity: 0.85
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
