import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Profile management panel — save, load, and delete display configurations.
Rectangle {
    id: root
    color: Theme.bgPanel
    radius: Theme.radiusL

    ColumnLayout {
        anchors { fill: parent; margins: Theme.spacingM }
        spacing: Theme.spacingS

        // ── Header ────────────────────────────────────────────────────
        Text {
            text: "Profiles"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeM
            font.bold: true
            Layout.fillWidth: true
        }

        // ── Save current as new profile ───────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Rectangle {
                Layout.fillWidth: true
                height: 32
                radius: Theme.radiusS
                color: Theme.bgCard
                border.color: nameField.activeFocus ? Theme.accent : Theme.border
                border.width: 1

                TextInput {
                    id: nameField
                    anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.textPrimary
                    selectionColor: Theme.accentGlow
                    font.pixelSize: Theme.fontSizeS
                    Text {
                        visible: !nameField.text && !nameField.activeFocus
                        text: "Profile name…"
                        color: Theme.textDisabled
                        font.pixelSize: Theme.fontSizeS
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            PanelButton {
                label: "Save"
                accent: true
                enabled: nameField.text.trim().length > 0
                onClicked: {
                    if (nameField.text.trim().length > 0) {
                        DisplayBridge.saveProfile(nameField.text.trim())
                        nameField.text = ""
                    }
                }
            }
        }

        // ── Profile list ──────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.bgCard
            radius: Theme.radiusS
            border.color: Theme.border
            clip: true

            ListView {
                id: profileList
                anchors { fill: parent; margins: 4 }
                model: DisplayBridge.profileNames
                spacing: 2
                clip: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: profileList.width
                    height: 36
                    radius: Theme.radiusS
                    color: selectedProfile === modelData
                        ? Qt.rgba(0.49, 0.42, 0.94, 0.18)
                        : (hovered ? Theme.bgHover : "transparent")

                    property bool hovered: false
                    property string profileName: modelData

                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 4 }
                        spacing: Theme.spacingS

                        Text {
                            Layout.fillWidth: true
                            text: modelData
                            color: selectedProfile === modelData
                                ? Theme.accent : Theme.textPrimary
                            font.pixelSize: Theme.fontSizeS
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                        }

                        // Delete button — only on hover
                        PanelButton {
                            visible: hovered || selectedProfile === modelData
                            label: "✕"
                            compact: true
                            onClicked: {
                                DisplayBridge.deleteProfile(modelData)
                                if (selectedProfile === modelData)
                                    selectedProfile = ""
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: parent.hovered = true
                        onExited: parent.hovered = false
                        onClicked: selectedProfile = profileName
                    }
                }

                Text {
                    visible: profileList.count === 0
                    anchors.centerIn: parent
                    text: "No profiles saved"
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontSizeS
                }
            }
        }

        // ── Actions for selected profile ──────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            Text {
                visible: selectedProfile !== ""
                text: selectedProfile
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeS
                elide: Text.ElideRight
                Layout.fillWidth: true
                verticalAlignment: Text.AlignVCenter
            }

            PanelButton {
                visible: selectedProfile !== ""
                label: "Load"
                accent: true
                onClicked: {
                    if (selectedProfile !== "")
                        DisplayBridge.loadProfile(selectedProfile)
                }
            }
        }
    }

    // ── Internal state ────────────────────────────────────────────────
    property string selectedProfile: ""

    // ── Reusable small button ─────────────────────────────────────────
    component PanelButton: Rectangle {
        property string label: ""
        property bool accent: false
        property bool compact: false
        signal clicked()
        property bool _enabled: enabled
        width: compact ? 28 : (btnLabel.implicitWidth + 20)
        height: 28
        radius: Theme.radiusS
        color: accent ? (mouseArea.pressed ? Qt.darker(Theme.accent, 1.2) : Theme.accent)
                       : (mouseArea.pressed ? Theme.bgHover : Theme.bgCard)
        border.color: accent ? "transparent" : Theme.border
        opacity: _enabled ? 1.0 : 0.4
        Text {
            id: btnLabel
            anchors.centerIn: parent
            text: parent.label
            color: accent ? Theme.textOnAccent : Theme.textSecondary
            font.pixelSize: Theme.fontSizeS
        }
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: parent._enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
