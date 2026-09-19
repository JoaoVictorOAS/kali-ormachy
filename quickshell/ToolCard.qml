import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property var toolData: null

    // Convenient accessors with safe defaults
    property string name: toolData ? (toolData.name || "") : ""
    property string binary: toolData ? (toolData.binary || "") : ""
    property string packageName: toolData ? (toolData.package || "") : ""
    property string mode: toolData ? (toolData.mode || "terminal") : "terminal"
    property string description: toolData ? (toolData.description || "") : ""
    property bool installed: toolData ? (toolData.installed === true) : false
    property var presets: (toolData && toolData.presets) ? toolData.presets : []
    property var params: (toolData && toolData.params) ? toolData.params : []

    // Omarchy / Catppuccin Mocha theme defaults
    property color cardBg: "#1e1e2e"
    property color cardHoverBg: "#232534"
    property color cardBorderColor: "#313244"
    property color cardHoverBorderColor: "#585b70"
    property color textColor: "#cdd6f4"
    property color subtextColor: "#a6adc8"
    property color descTextColor: "#bac2de"
    property color accentBlue: "#89b4fa"
    property color accentMauve: "#cba6f7"
    property color successGreen: "#a6e3a1"
    property color errorRed: "#f38ba8"
    property color chipBg: "#313244"
    property color chipHoverBg: "#45475a"

    signal launchRequested(string toolName, string presetName)
    signal installRequested(string packageName, string toolName)

    implicitWidth: 520
    implicitHeight: contentColumn.implicitHeight + 24
    radius: 10

    color: cardMouseArea.containsMouse ? cardHoverBg : cardBg
    border.color: cardMouseArea.containsMouse ? cardHoverBorderColor : cardBorderColor
    border.width: 1

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        // Header Row: Mode Icon, Name, Binary, and Installed Status Badge
        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            // Mode icon (terminal vs gui)
            Rectangle {
                implicitWidth: 28
                implicitHeight: 28
                radius: 6
                color: root.mode === "gui" ? "#312344" : "#1e293b"
                border.color: root.mode === "gui" ? root.accentMauve : root.accentBlue
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: root.mode === "gui" ? "󰍹" : "󰞷"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: root.mode === "gui" ? root.accentMauve : root.accentBlue
                }
            }

            // Tool Title
            Text {
                text: root.name
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                font.weight: Font.Bold
                color: root.textColor
            }

            // Binary pill
            Rectangle {
                implicitWidth: binLabel.implicitWidth + 10
                implicitHeight: 20
                radius: 4
                color: "#181825"
                border.color: "#313244"
                border.width: 1

                Text {
                    id: binLabel
                    anchors.centerIn: parent
                    text: root.binary
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    color: root.subtextColor
                }
            }

            Item {
                Layout.fillWidth: true
            }

            // Installed Status Badge
            Rectangle {
                implicitWidth: badgeRow.implicitWidth + 14
                implicitHeight: 22
                radius: 11
                color: root.installed ? "#1c3a27" : "#3d1f28"
                border.color: root.installed ? root.successGreen : root.errorRed
                border.width: 1

                RowLayout {
                    id: badgeRow
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        text: root.installed ? "󰄬" : "󰅚"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: root.installed ? root.successGreen : root.errorRed
                    }

                    Text {
                        text: root.installed ? "Instalado" : "Não instalado"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        color: root.installed ? root.successGreen : root.errorRed
                    }
                }
            }
        }

        // Tool Description
        Text {
            text: root.description
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            color: root.descTextColor
            opacity: 0.9
            lineHeight: 1.25
        }

        // Presets Section (if available)
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.presets && root.presets.length > 0

            Text {
                text: "Presets de Execução:"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: "#6c7086"
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: root.presets

                    delegate: Rectangle {
                        id: presetChip
                        implicitWidth: presetRow.implicitWidth + 14
                        implicitHeight: 26
                        radius: 6
                        color: chipMouse.containsMouse ? root.chipHoverBg : root.chipBg
                        border.color: chipMouse.containsMouse ? root.accentBlue : "#45475a"
                        border.width: 1

                        RowLayout {
                            id: presetRow
                            anchors.centerIn: parent
                            spacing: 6

                            Text {
                                text: "󰐊"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 10
                                color: root.accentBlue
                            }

                            Text {
                                text: modelData.name
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                color: root.textColor
                            }
                        }

                        MouseArea {
                            id: chipMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.launchRequested(root.name, modelData.name);
                            }
                        }
                    }
                }
            }
        }

        // Footer Action Row
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Item {
                Layout.fillWidth: true
            }

            // Launch Button (if installed)
            Rectangle {
                visible: root.installed
                implicitWidth: launchBtnRow.implicitWidth + 16
                implicitHeight: 28
                radius: 6
                color: launchBtnMouse.containsMouse ? "#74c7ec" : root.accentBlue

                RowLayout {
                    id: launchBtnRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "▶"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: "#11111b"
                    }

                    Text {
                        text: "Executar"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#11111b"
                    }
                }

                MouseArea {
                    id: launchBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.launchRequested(root.name, "")
                }
            }

            // Install Button (if not installed)
            Rectangle {
                visible: !root.installed
                implicitWidth: installBtnRow.implicitWidth + 16
                implicitHeight: 28
                radius: 6
                color: installBtnMouse.containsMouse ? "#fab387" : "#f38ba8"

                RowLayout {
                    id: installBtnRow
                    anchors.centerIn: parent
                    spacing: 6

                    Text {
                        text: "󰐥"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        color: "#11111b"
                    }

                    Text {
                        text: "Instalar (" + (root.packageName || root.binary) + ")"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: "#11111b"
                    }
                }

                MouseArea {
                    id: installBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        let pkg = (root.packageName || root.binary || root.name).trim();
                        root.installRequested(pkg, root.name);
                    }
                }
            }
        }
    }

    // Catch-all card click: launches tool if installed, triggers install if missing
    MouseArea {
        id: cardMouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        z: -1
        onClicked: {
            if (root.installed) {
                root.launchRequested(root.name, "");
            } else {
                let pkg = (root.packageName || root.binary || root.name).trim();
                root.installRequested(pkg, root.name);
            }
        }
    }
}
