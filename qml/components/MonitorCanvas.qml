import QtQuick
import QtQuick.Controls
import "../theme"

Item {
    id: root

    property string selectedOutput: ""
    property real canvasScale: 1.0
    readonly property int padding: 24

    signal outputSelected(string name)

    // Compute a scale factor that fits all monitors in the canvas
    property var _bounds: {
        var minX = 0, minY = 0, maxX = 1, maxY = 1
        for (var i = 0; i < DisplayBridge.outputs.length; i++) {
            var o = DisplayBridge.outputs[i]
            if (!o.enabled) continue
            minX = Math.min(minX, o.pos_x)
            minY = Math.min(minY, o.pos_y)
            maxX = Math.max(maxX, o.pos_x + o.logical_width)
            maxY = Math.max(maxY, o.pos_y + o.logical_height)
        }
        return { minX: minX, minY: minY, w: maxX - minX, h: maxY - minY }
    }

    property real _fitScale: {
        var usableW = width - padding * 2
        var usableH = height - padding * 2
        if (_bounds.w <= 0 || _bounds.h <= 0) return 1
        var sx = usableW / _bounds.w
        var sy = usableH / _bounds.h
        return Math.min(sx, sy, 0.25)   // cap at 0.25x to keep monitors visible
    }

    // Center offset so monitors appear centered in the canvas
    property real _offsetX: (width - _bounds.w * _fitScale) / 2 - _bounds.minX * _fitScale
    property real _offsetY: (height - _bounds.h * _fitScale) / 2 - _bounds.minY * _fitScale

    Rectangle {
        anchors.fill: parent
        color: Theme.bgCard
        radius: Theme.radiusL

        // Grid dots background
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

        // Monitor blocks
        Repeater {
            model: DisplayBridge.outputs
            delegate: MonitorBlock {
                // Capture modelData into a stable property for use in signal handlers
                required property var modelData
                outputData: modelData
                selected: modelData.name === root.selectedOutput
                fitScale: root._fitScale
                offsetX: root._offsetX
                offsetY: root._offsetY
                onClicked: {
                    root.selectedOutput = outputData.name
                    root.outputSelected(outputData.name)
                }
                onMoved: function(name, nx, ny) {
                    DisplayBridge.setPosition(name, nx, ny)
                }
            }
        }
    }
}
