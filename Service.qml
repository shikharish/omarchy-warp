import QtQuick
import Quickshell
import Quickshell.Io

// Talks to warp-svc through warp-cli. Every command is an argv array with
// fixed arguments (modes come from a closed list), so nothing from the CLI
// or the network is ever interpolated into a shell.
Item {
  id: root

  property var settings: ({})
  // The panel sets this; details (settings, registration, exit trace) are
  // only fetched while someone is looking at them.
  property bool detailsWanted: false

  readonly property var knownModes: ["warp", "warp+doh", "doh", "proxy"]

  property bool installed: true
  property bool serviceUp: true
  property string status: ""
  property string reason: ""
  property string mode: ""
  property string protocol: ""
  property string accountType: ""
  property string exitIp: ""
  property string exitColo: ""
  property string exitLoc: ""
  property string settingMode: ""
  // Raw CLI message of the last failed action; the panel adds the wording.
  property string errorKind: ""
  property string errorText: ""

  // -1 follows the real state; 0/1 is a click the daemon has not caught up
  // with yet, so the switch throws immediately.
  property int _desired: -1
  readonly property bool connected: status === "Connected"
  readonly property bool active: _desired === -1 ? (connected || status === "Connecting") : _desired === 1
  readonly property bool transitioning: _desired !== -1 || status === "Connecting"
  readonly property bool busy: toggleProc.running || modeProc.running

  readonly property int refreshIntervalSec: {
    var n = parseInt(String(settings && settings.refreshIntervalSec !== undefined ? settings.refreshIntervalSec : 5), 10)
    return isFinite(n) ? Math.max(2, Math.min(300, n)) : 5
  }

  function clip(value, max) {
    var s = String(value === undefined || value === null ? "" : value)
    return s.length > max ? s.slice(0, max) : s
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function refreshDetails() {
    if (!installed) return
    if (!settingsProc.running) settingsProc.running = true
    if (!registrationProc.running) registrationProc.running = true
    refreshTrace()
  }

  function refreshTrace() {
    if (traceProc.running) return
    traceProc.running = true
  }

  function toggle() {
    if (!installed || toggleProc.running) return
    var turnOn = !active
    _desired = turnOn ? 1 : 0
    errorKind = ""
    errorText = ""
    desiredTimeout.restart()
    toggleProc.command = ["warp-cli", "--accept-tos", turnOn ? "connect" : "disconnect"]
    toggleProc.running = true
  }

  function setMode(next) {
    if (!installed || modeProc.running || knownModes.indexOf(next) === -1 || next === mode) return
    settingMode = next
    errorKind = ""
    errorText = ""
    modeProc.command = ["warp-cli", "--accept-tos", "mode", next]
    modeProc.running = true
  }

  function parseStatus(text) {
    try {
      var data = JSON.parse(text)
      status = clip(data.status, 40)
      reason = clip(data.reason, 80)
      serviceUp = true
    } catch (e) {
      serviceUp = false
      status = ""
    }
    if (_desired === 1 && status === "Connected") _desired = -1
    if (_desired === 0 && status === "Disconnected") _desired = -1
  }

  function parseSettings(text) {
    try {
      var s = JSON.parse(text).settings || {}
      mode = clip(s.operation_mode, 20)
      protocol = clip(s.warp_tunnel_protocol, 20)
    } catch (e) {}
  }

  function parseRegistration(text) {
    try {
      var data = JSON.parse(text)
      accountType = data.account ? clip(data.account.type, 20) : ""
    } catch (e) {}
  }

  // cdn-cgi/trace is key=value lines. Keep only the fields shown, and only
  // when they look like what Cloudflare documents for them.
  function parseTrace(text) {
    var ip = "", colo = "", loc = ""
    var lines = clip(text, 2048).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var eq = lines[i].indexOf("=")
      if (eq <= 0) continue
      var key = lines[i].slice(0, eq)
      var value = lines[i].slice(eq + 1).trim()
      if (key === "ip" && /^[0-9a-fA-F:.]{2,45}$/.test(value)) ip = value
      else if (key === "colo" && /^[A-Z]{3}$/.test(value)) colo = value
      else if (key === "loc" && /^[A-Z]{2}$/.test(value)) loc = value
    }
    exitIp = ip
    exitColo = colo
    exitLoc = loc
  }

  function failAction(kind, stdout, stderr) {
    var msg = String(stderr || "").trim() || String(stdout || "").trim() || "exit code"
    errorKind = kind
    errorText = clip(msg.split("\n")[0], 160)
  }

  onConnectedChanged: if (detailsWanted) refreshTrace()
  onDetailsWantedChanged: if (detailsWanted) { refresh(); refreshDetails() }

  Process {
    id: whichProc
    running: true
    command: ["sh", "-c", "command -v warp-cli >/dev/null"]
    onExited: function(exitCode) {
      root.installed = exitCode === 0
      if (root.installed) root.refresh()
    }
  }

  Process {
    id: statusProc
    command: ["warp-cli", "-j", "--accept-tos", "status"]
    stdout: StdioCollector { id: statusOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseStatus(String(statusOut.text || ""))
      else root.serviceUp = false
    }
  }

  Process {
    id: settingsProc
    command: ["warp-cli", "-j", "--accept-tos", "settings", "list"]
    stdout: StdioCollector { id: settingsOut; waitForEnd: true }
    onExited: function(exitCode) { if (exitCode === 0) root.parseSettings(String(settingsOut.text || "")) }
  }

  Process {
    id: registrationProc
    command: ["warp-cli", "-j", "--accept-tos", "registration", "show"]
    stdout: StdioCollector { id: registrationOut; waitForEnd: true }
    onExited: function(exitCode) { if (exitCode === 0) root.parseRegistration(String(registrationOut.text || "")) }
  }

  // Fixed HTTPS endpoint, 5s cap, 4 KiB cap; only runs while the panel is open.
  Process {
    id: traceProc
    command: ["curl", "-sS", "--max-time", "5", "--max-filesize", "4096", "https://www.cloudflare.com/cdn-cgi/trace"]
    stdout: StdioCollector { id: traceOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode === 0) root.parseTrace(String(traceOut.text || ""))
      else root.parseTrace("")
    }
  }

  Process {
    id: toggleProc
    stdout: StdioCollector { id: toggleOut; waitForEnd: true }
    stderr: StdioCollector { id: toggleErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root._desired = -1
        root.failAction("toggle", toggleOut.text, toggleErr.text)
      }
      root.refresh()
    }
  }

  Process {
    id: modeProc
    stdout: StdioCollector { id: modeOut; waitForEnd: true }
    stderr: StdioCollector { id: modeErr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.failAction("mode", modeOut.text, modeErr.text)
      root.settingMode = ""
      root.refresh()
      root.refreshDetails()
    }
  }

  // A switch that never reaches the asked-for state falls back to the truth.
  Timer {
    id: desiredTimeout
    interval: 20000
    onTriggered: root._desired = -1
  }

  // Poll fast while a change settles, at the configured pace otherwise.
  Timer {
    interval: root.transitioning ? 1000 : root.refreshIntervalSec * 1000
    running: root.installed
    repeat: true
    onTriggered: root.refresh()
  }
}
