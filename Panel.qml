import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "shikhar.warp"
  ipcTarget: "shikhar.warp"
  manageIpc: false

  readonly property var modes: [
    { id: "warp", label: strings.t("modeWarp"), detail: strings.t("modeWarpDetail") },
    { id: "warp+doh", label: strings.t("modeWarpDoh"), detail: strings.t("modeWarpDohDetail") },
    { id: "doh", label: strings.t("modeDoh"), detail: strings.t("modeDohDetail") },
    { id: "proxy", label: strings.t("modeProxy"), detail: strings.t("modeProxyDetail") }
  ]

  property string focusSection: "header"
  property int modeIndex: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Commons.Color.foreground
  readonly property color urgent: bar ? bar.urgent : Commons.Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color barIconColor: warp.active ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Commons.Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Commons.Color.accent) : "transparent"
  readonly property bool usable: warp.installed && warp.serviceUp

  readonly property string statusLine: {
    if (!warp.installed) return strings.t("notInstalled")
    if (!warp.serviceUp) return strings.t("serviceDown")
    if (warp._desired === 1 || (warp._desired === -1 && warp.status === "Connecting")) return strings.t("connecting")
    if (warp._desired === 0) return strings.t("disconnecting")
    if (warp.connected) {
      var where = [warp.exitColo, warp.exitLoc].filter(function(s) { return s !== "" }).join(" · ")
      return where !== "" ? strings.t("connectedAt").arg(where) : strings.t("connected")
    }
    return strings.t("disconnected")
  }

  readonly property string errorLine: {
    if (warp.errorText === "") return ""
    return strings.t(warp.errorKind === "mode" ? "modeFailed" : "toggleFailed").arg(warp.errorText)
  }

  function accountLabel(type) {
    if (type === "free") return strings.t("accountFree")
    if (type === "limited" || type === "unlimited" || type === "plus") return strings.t("accountPlus")
    if (type === "team") return strings.t("accountTeam")
    return type
  }

  function copyIp() {
    if (warp.exitIp === "") return
    Quickshell.execDetached(["wl-copy", warp.exitIp])
    Quickshell.execDetached(["notify-send", "-t", "2000", strings.t("title"), strings.t("copied").arg(warp.exitIp)])
  }

  function moveCursor(dy) {
    cursorActive = true
    if (!usable) { focusSection = "header"; return }
    if (focusSection === "header") {
      if (dy > 0) { focusSection = "modes"; modeIndex = 0 }
    } else if (dy < 0) {
      if (modeIndex <= 0) focusSection = "header"
      else modeIndex--
    } else if (modeIndex < modes.length - 1) {
      modeIndex++
    }
  }

  function activateCursor() {
    if (focusSection === "header") warp.toggle()
    else warp.setMode(modes[modeIndex].id)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    focusSection = "header"
    Qt.callLater(function() { if (panel.loadedContent) panel.loadedContent.forceActiveFocus() })
  }

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  Service {
    id: warp
    settings: root.settings
    detailsWanted: root.opened
  }

  ShellIpc {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function toggleWarp(): string { warp.toggle(); return "ok" }
    function status(): string { return warp.status }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.opened ? "" : root.statusLine
    iconComponent: Component {
      Item {
        WarpIcon {
          x: (parent.width - width) / 2
          y: (parent.height - height) / 2
          iconSize: button.iconSize
          fontFamily: root.fontFamily
          color: root.barIconColor
          crossed: !warp.active
          pulsing: warp.transitioning
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) warp.toggle()
      else if (buttonCode === Qt.MiddleButton) { warp.refresh(); if (root.opened) warp.refreshDetails() }
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight, Style.space(560))

    content: PanelKeyCatcher {
      id: keyCatcher
      implicitHeight: column.implicitHeight
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy !== 0) root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "t" || t === "T") warp.toggle()
        else if (t === "r" || t === "R") { warp.refresh(); warp.refreshDetails() }
        else if (t === "c" || t === "C") root.copyIp()
      }

      Column {
        id: column
        width: parent.width
        spacing: Style.space(12)

        Item {
          id: header
          width: parent.width
          implicitHeight: hero.implicitHeight
          readonly property bool ringVisible: root.cursorActive && root.focusSection === "header" && root.usable

          PanelHero {
            id: hero
            width: parent.width
            title: strings.t("title")
            meta: root.statusLine
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: warp.active ? 1.0 : 0.5
            iconComponent: Component {
              WarpIcon {
                iconSize: Style.font.display
                fontFamily: root.fontFamily
                color: warp.active ? root.foreground : root.dim
                crossed: !warp.active
                pulsing: warp.transitioning
              }
            }

            trailingControl: Component {
              ToggleSwitch {
                id: powerSwitch
                visible: root.usable
                checked: warp.active
                busy: warp.busy || warp.transitioning
                hasCursor: header.ringVisible
                foreground: hero.foreground
                onHovered: function(on) { if (on) { root.cursorActive = true; root.focusSection = "header" } }
                onToggled: warp.toggle()

                PanelToolTip {
                  visible: powerSwitch.containsMouse
                  text: warp.active ? strings.t("turnOff") : strings.t("turnOn")
                  fontFamily: hero.fontFamily
                }
              }
            }
          }
        }

        Text {
          visible: root.errorLine !== ""
          width: parent.width
          text: root.errorLine
          textFormat: Text.PlainText
          color: root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { visible: root.usable; foreground: root.foreground }

        Column {
          visible: root.usable
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: strings.t("mode")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Column {
            width: parent.width
            spacing: Style.space(6)

            Repeater {
              model: root.modes
              ModeRow {
                required property var modelData
                required property int index
                width: parent.width
                modeId: modelData.id
                label: modelData.label
                detail: modelData.detail
                rowIndex: index
              }
            }
          }
        }

        PanelSeparator { visible: root.usable; foreground: root.foreground }

        Column {
          visible: root.usable
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: strings.t("details")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          DetailRow {
            label: strings.t("location")
            value: [warp.exitColo, warp.exitLoc].filter(function(s) { return s !== "" }).join(" · ") || strings.t("loading")
          }

          DetailRow {
            label: strings.t("publicIp")
            value: warp.exitIp || strings.t("loading")
            copyable: warp.exitIp !== ""
          }

          DetailRow {
            label: strings.t("protocol")
            value: warp.protocol === "masque" ? "MASQUE" : (warp.protocol === "wireguard" ? "WireGuard" : (warp.protocol || strings.t("loading")))
          }

          DetailRow {
            label: strings.t("account")
            value: root.accountLabel(warp.accountType) || strings.t("loading")
          }
        }
      }
    }
  }

  component ModeRow: CursorSurface {
    id: modeRow
    property string modeId: ""
    property string label: ""
    property string detail: ""
    property int rowIndex: 0
    readonly property bool selectedMode: warp.mode === modeId
    readonly property bool settingThis: warp.settingMode === modeId

    hasCursor: root.cursorActive && root.focusSection === "modes" && root.modeIndex === rowIndex
    current: selectedMode || settingThis
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: modeInner.implicitHeight + Style.spacing.lg

    RowLayout {
      id: modeInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        textFormat: Text.PlainText
        text: modeRow.selectedMode ? "\udb81\udc3e" : "\udb81\udc3d"
        color: modeRow.current ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        Layout.preferredWidth: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignVCenter
        opacity: modeRow.settingThis ? 0.45 : 1.0
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: modeRow.label
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: modeRow.selectedMode
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: modeRow.detail
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: warp.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
      enabled: !warp.busy
      onEntered: { root.cursorActive = true; root.focusSection = "modes"; root.modeIndex = modeRow.rowIndex }
      onClicked: warp.setMode(modeRow.modeId)
    }
  }

  component DetailRow: Item {
    id: detailRow
    property string label: ""
    property string value: ""
    property bool copyable: false

    width: parent ? parent.width : 0
    implicitHeight: Math.max(labelText.implicitHeight, copyBtn.visible ? copyBtn.implicitHeight : 0)

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        id: labelText
        textFormat: Text.PlainText
        text: detailRow.label
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText
        text: detailRow.value
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideMiddle
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      PanelActionButton {
        id: copyBtn
        visible: detailRow.copyable
        iconText: "\udb80\udd8f"
        tooltipText: strings.t("copyIp")
        foreground: root.foreground
        fontFamily: root.fontFamily
        Layout.alignment: Qt.AlignVCenter
        onClicked: root.copyIp()
      }
    }
  }
}
