import QtQuick
import qs.Commons
import qs.Commons as Commons

// Cloud mark with the same off-state slash the Tailscale icon uses, and a
// small dot when WARP still needs setting up.
Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Commons.Color.foreground
  property string fontFamily: Style.font.family
  property bool crossed: false
  property bool pulsing: false
  property bool needsSetup: false
  property color badgeColor: Commons.Color.urgent

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Text {
    id: glyph
    anchors.centerIn: parent
    text: "\udb80\udd5f"
    textFormat: Text.PlainText
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: Math.round(root.iconSize * 1.15)

    SequentialAnimation on opacity {
      running: root.pulsing && !Style.reduceMotion
      loops: Animation.Infinite
      onRunningChanged: if (!running) glyph.opacity = 1.0
      NumberAnimation { to: 0.4; duration: Style.duration(420); easing.type: Easing.InOutQuad }
      NumberAnimation { to: 1.0; duration: Style.duration(420); easing.type: Easing.InOutQuad }
    }
  }

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: parent.width * 1.22
    height: Math.max(2, parent.height * 0.14)
    radius: height / 2
    color: root.color
    rotation: -45
  }

  Rectangle {
    visible: root.needsSetup
    width: Math.max(4, Math.round(root.iconSize * 0.36))
    height: width
    radius: width / 2
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: -Math.round(width * 0.2)
    anchors.topMargin: Math.round(width * 0.1)
    color: root.badgeColor
  }
}
