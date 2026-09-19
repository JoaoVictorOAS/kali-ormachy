import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Rectangle {
    id: root

    property string categoryId: ""
    property string categoryName: ""
    property string icon: ""
    property int toolCount: 0
    property bool active: false

    // Omarchy / Catppuccin Mocha theme defaults
    property color accentColor: "#89b4fa"
    property color activeBgColor: "#313244"
    property color inactiveBgColor: "transparent"
    property color hoverBgColor: "#262837"
    property color textColor: "#cdd6f4"
    property color activeTextColor: "#ffffff"
    property color mutedTextColor: "#a6adc8"

    signal clicked()

    implicitWidth: 230
    implicitHeight: 46
    radius: 8

    color: active ? activeBgColor : (mouseArea.containsMouse ? hoverBgColor : inactiveBgColor)

    Behavior on color {
        ColorAnimation { duration: 150 }
    }

    // Left active indicator strip
    Rectangle {
        id: activeIndicator
        width: 3
        height: 24
        radius: 1.5
        color: root.accentColor
        visible: root.active
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 4
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 10

        Text {
            id: iconText
            text: root.icon || "󰘳"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 18
            color: root.active ? root.accentColor : (mouseArea.containsMouse ? root.textColor : root.mutedTextColor)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 26
        }

        Text {
            id: nameText
            text: root.categoryName
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            font.weight: root.active ? Font.DemiBold : Font.Normal
            color: root.active ? root.activeTextColor : root.textColor
            Layout.fillWidth: true
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            Layout.alignment: Qt.AlignVCenter
        }

        Rectangle {
            id: countBadge
            visible: root.toolCount > 0
            implicitWidth: Math.max(22, countLabel.implicitWidth + 10)
            implicitHeight: 20
            radius: 10
            color: root.active ? root.accentColor : "#45475a"
            Layout.alignment: Qt.AlignVCenter

            Text {
                id: countLabel
                anchors.centerIn: parent
                text: root.toolCount.toString()
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
                font.weight: Font.Bold
                color: root.active ? "#11111b" : root.textColor
            }
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
