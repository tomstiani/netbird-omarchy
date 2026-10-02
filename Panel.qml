import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Names.js" as Names

Panel {
  id: root
  moduleName: "tomstiani.netbird"
  ipcTarget: "tomstiani.netbird"
  manageIpc: false

  // An empty URL uses NetBird's existing profile (or its default login server).
  // An empty daemon address lets the CLI discover the local service.
  readonly property string managementUrl: String(setting("managementUrl", "") || "").trim()
  readonly property string daemonAddress: String(setting("daemonAddress", "") || "").trim()
  property string managementEndpoint: ""
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property string state: "Checking…"
  property string ip: ""
  property string fqdn: ""
  property int connectedPeers: 0
  property int totalPeers: 0
  property var peers: []
  readonly property var devicePeers: peers.filter(function(peer) { return !Names.isProxy(peer) })
  readonly property var proxyPeers: peers.filter(function(peer) { return Names.isProxy(peer) })
  property bool proxiesExpanded: false
  property string error: ""
  property string actionError: ""
  property string copiedIp: ""
  readonly property bool connected: state === "Connected"
  readonly property bool actionBusy: upProcess.running || downProcess.running
  readonly property bool canConnect: state === "NeedsLogin" || state === "Disconnected" || state === "Stopped"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function daemonArgs() {
    return daemonAddress ? ["--daemon-addr", daemonAddress] : []
  }

  function managementArgs() {
    return managementUrl ? ["--management-url", managementUrl] : []
  }

  function refresh() {
    if (statusProcess.running) return
    statusProcess.command = ["netbird"].concat(daemonArgs(), ["status", "--json"])
    statusProcess.running = true
    watchdog.restart()
  }

  function connect() {
    if (!canConnect || actionBusy) return
    actionError = ""
    if (state === "NeedsLogin") {
      // Keep SSO and setup-key entry in a real terminal; never persist secrets in QML.
      close()
      var args = ["netbird"].concat(daemonArgs(), ["up"], managementArgs())
      var shellCommand = args.map(function(arg) { return Util.shellQuote(arg) }).join(" ") + "; exec bash"
      Quickshell.execDetached(["omarchy", "launch", "terminal", "bash", "-lc", shellCommand])
    } else {
      upProcess.command = ["netbird"].concat(daemonArgs(), ["up"], managementArgs())
      upProcess.running = true
    }
  }

  function disconnect() {
    if (actionBusy || !connected) return
    actionError = ""
    downProcess.command = ["netbird"].concat(daemonArgs(), ["down"])
    downProcess.running = true
  }

  function copyPeerIp(peer) {
    var address = String(peer.netbirdIp || "")
    if (!address) return
    Quickshell.execDetached(["wl-copy", address])
    copiedIp = address
    copiedReset.restart()
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
    function status(): string { return root.state }
  }

  Timer {
    interval: root.opened ? 5000 : 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Timer {
    id: watchdog
    interval: 12000
    onTriggered: {
      if (statusProcess.running) {
        statusProcess.running = false
        root.error = "NetBird status timed out"
      }
    }
  }
  Timer {
    id: actionRefresh
    interval: 1000
    onTriggered: root.refresh()
  }
  Timer {
    id: copiedReset
    interval: 2000
    onTriggered: root.copiedIp = ""
  }

  Process {
    id: statusProcess
    command: []
    stdout: StdioCollector { id: statusOutput; waitForEnd: true }
    stderr: StdioCollector { id: statusError; waitForEnd: true }
    onExited: function(code) {
      watchdog.stop()
      if (code !== 0) {
        root.state = "Unavailable"
        root.ip = ""
        root.fqdn = ""
        root.managementEndpoint = ""
        root.peers = []
        root.connectedPeers = 0
        root.totalPeers = 0
        root.error = String(statusError.text || "NetBird daemon unavailable").trim().slice(0, 180)
        return
      }
      try {
        var data = JSON.parse(statusOutput.text)
        root.state = String(data.daemonStatus || "Unknown")
        root.ip = String(data.netbirdIp || "")
        root.fqdn = String(data.fqdn || "")
        root.managementEndpoint = String((data.management || {}).url || "")
        root.connectedPeers = Number((data.peers || {}).connected || 0)
        root.totalPeers = Number((data.peers || {}).total || 0)
        root.peers = Names.sortedPeers(Array.isArray((data.peers || {}).details) ? data.peers.details : [])
        root.error = String((data.management || {}).error || "")
      } catch (e) {
        root.state = "Unavailable"
        root.error = "Could not parse NetBird status"
      }
    }
  }

  Process {
    id: upProcess
    command: []
    stdout: StdioCollector { id: upOutput; waitForEnd: true }
    stderr: StdioCollector { id: upError; waitForEnd: true }
    onExited: function(code) {
      root.actionError = code === 0 ? "" : String(upError.text || upOutput.text || "Connect failed").trim().slice(0, 180)
      actionRefresh.restart()
    }
  }

  Process {
    id: downProcess
    command: []
    stdout: StdioCollector { id: downOutput; waitForEnd: true }
    stderr: StdioCollector { id: downError; waitForEnd: true }
    onExited: function(code) {
      root.actionError = code === 0 ? "" : String(downError.text || downOutput.text || "Disconnect failed").trim().slice(0, 180)
      actionRefresh.restart()
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Text {
        text: "󰖂"
        color: root.connected ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.icon
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: fittedContentWidth(Style.space(360))
    contentHeight: fittedContentHeight(content.implicitHeight, Style.space(500))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r") root.refresh()
        else if (t === "c") root.connect()
        else if (t === "d") root.disconnect()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        Column {
          id: content
          width: parent.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "NetBird"
            meta: root.state
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰖂"
                color: root.connected ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              Button {
                text: root.connected ? (downProcess.running ? "Disconnecting…" : "Disconnect")
                  : root.state === "NeedsLogin" ? "Sign in"
                  : upProcess.running || root.state === "Connecting" ? "Connecting…" : "Connect"
                visible: root.connected || (root.state !== "Unavailable" && root.state !== "Checking…")
                enabled: !root.actionBusy && (root.connected || root.canConnect)
                onClicked: root.connected ? root.disconnect() : root.connect()
              }
            }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.fqdn || root.managementEndpoint || root.managementUrl || "NetBird"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
          Text {
            visible: root.ip !== ""
            text: root.ip
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Text {
            visible: root.actionError !== "" || root.error !== ""
            width: parent.width
            textFormat: Text.PlainText
            text: root.actionError || root.error
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator { visible: root.connected; foreground: root.foreground }
          RowLayout {
            visible: root.connected
            width: parent.width
            spacing: Style.space(6)
            PanelSectionHeader {
              text: "PEERS · " + root.totalPeers
              foreground: root.foreground
              fontFamily: root.fontFamily
              Layout.alignment: Qt.AlignVCenter
            }
            Item { Layout.fillWidth: true; implicitHeight: 1 }
            Text {
              text: root.connectedPeers + " ACTIVE " + (root.connectedPeers === 1 ? "LINK" : "LINKS")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              Layout.alignment: Qt.AlignVCenter
            }
            PanelActionButton {
              iconText: "󰑐"
              tooltipText: "Refresh peers"
              foreground: root.foreground
              fontFamily: root.fontFamily
              Layout.alignment: Qt.AlignVCenter
              onClicked: root.refresh()
            }
          }
          Text {
            visible: root.connected && root.peers.length === 0
            text: "No peers available"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
          Column {
            id: deviceList
            visible: root.connected && root.devicePeers.length > 0
            width: parent.width
            spacing: Style.space(4)
            PanelSectionHeader {
              text: "DEVICES · " + root.devicePeers.length
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Repeater {
              model: root.connected ? root.devicePeers : []
              PeerRow { width: deviceList.width }
            }
          }
          Column {
            id: proxyList
            visible: root.connected && root.proxyPeers.length > 0
            width: parent.width
            spacing: Style.space(4)
            Item {
              id: proxyHeader
              width: parent.width
              implicitHeight: Style.space(28)
              Rectangle {
                anchors.fill: parent
                radius: Style.cornerRadius
                color: proxyMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
                Behavior on color { ColorAnimation { duration: 160 } }
              }
              PanelSectionHeader {
                text: "PROXIES · " + root.proxyPeers.length
                foreground: root.foreground
                fontFamily: root.fontFamily
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                anchors.right: parent.right
                anchors.rightMargin: Style.space(10)
                anchors.verticalCenter: parent.verticalCenter
                text: root.proxiesExpanded ? "▾" : "▸"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              MouseArea {
                id: proxyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.proxiesExpanded = !root.proxiesExpanded
              }
            }
            Repeater {
              model: root.connected && root.proxiesExpanded ? root.proxyPeers : []
              PeerRow { width: proxyList.width }
            }
          }
        }
      }
    }
  }

  component PeerRow: Item {
    id: peerRow
    required property var modelData
    readonly property bool copied: root.copiedIp !== "" && root.copiedIp === String(modelData.netbirdIp || "")
    implicitHeight: peerDetails.implicitHeight + Style.space(8)
    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: peerRow.copied ? Style.selectedFillFor(root.foreground, Color.accent)
            : peerMouse.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
      Behavior on color { ColorAnimation { duration: 160 } }
    }
    Column {
      id: peerDetails
      x: Style.space(10)
      y: Style.space(4)
      width: parent.width - Style.space(40)
      spacing: Style.space(2)
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: Names.displayName(peerRow.modelData)
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: peerRow.copied ? "Copied IP to clipboard" : String(peerRow.modelData.netbirdIp || "") + " · " + String(peerRow.modelData.status || "Unknown")
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }
    Text {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: peerRow.copied ? "󰄬" : "󰆏"
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.icon
      opacity: peerMouse.containsMouse || peerRow.copied ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }
    MouseArea {
      id: peerMouse
      anchors.fill: parent
      enabled: !!peerRow.modelData.netbirdIp
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.copyPeerIp(peerRow.modelData)
    }
  }
}
