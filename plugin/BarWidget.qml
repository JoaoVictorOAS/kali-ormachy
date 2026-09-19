import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "kali-ormachy"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf327"
    slotSize: Style.bar.statusSlot
    tooltipText: "Kali-Ormachy Security Launcher"
    onPressed: function(btn) {
      if (!root.bar) return
      if (btn === Qt.RightButton) {
        root.bar.run("kali-ormachy-rofi")
      } else {
        root.bar.run("quickshell -d -p " + Quickshell.env("HOME") + "/.config/ormachy-kali/quickshell/")
      }
    }
  }
}
