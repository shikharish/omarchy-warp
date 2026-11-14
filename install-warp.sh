#!/usr/bin/env bash
# Sets up Cloudflare WARP for the shikhar.warp Omarchy plugin: installs the
# client from the AUR, starts its warp-svc service and registers this device.
# Every step is skipped when it is already done, so running it again is safe.
# With --check it only reports the state and changes nothing.

set -euo pipefail

readonly TERMS_URL="https://www.cloudflare.com/application/terms/"
readonly SERVICE="warp-svc"
readonly DAEMON_WAIT_SECONDS=20

usage() {
  cat <<'EOF'
Usage: install-warp.sh [--check]

Installs Cloudflare WARP, starts its warp-svc service and registers this
device. Steps that are already done are skipped.

  --check   only show what is installed and running; change nothing
EOF
}

say() { printf '%s\n' "$*"; }
step() { printf '\n%s\n' "$*"; }

fail() {
  printf '\nError: %s\n' "$*" >&2
  exit 1
}

# Yes/no question; anything but a clear yes is no.
ask() {
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$1"
  else
    local reply=""
    read -r -p "$1 [y/N] " reply || return 1
    [[ $reply =~ ^[Yy]([Ee][Ss])?$ ]]
  fi
}

package_for_arch() {
  case "$(uname -m)" in
    x86_64) echo "cloudflare-warp-bin" ;;
    aarch64) echo "cloudflare-warp-nox-bin" ;;
    *) return 1 ;;
  esac
}

# warp-cli asks to accept Cloudflare's terms on first use; --accept-tos
# answers that, as the plugin does on every call.
is_installed() { command -v warp-cli >/dev/null 2>&1; }
service_running() { systemctl is-active --quiet "$SERVICE" >/dev/null 2>&1; }
daemon_answers() { warp-cli --accept-tos status >/dev/null 2>&1; }
is_registered() { warp-cli --accept-tos registration show >/dev/null 2>&1; }
is_connected() {
  local out
  out=$(warp-cli -j --accept-tos status 2>/dev/null) || return 1
  [[ $out =~ \"status\":\ *\"Connected\" ]]
}

yes_no() { if "$@"; then echo "yes"; else echo "no"; fi; }

check() {
  local installed running registered connected pkg
  installed=$(yes_no is_installed)
  running=$(yes_no service_running)
  registered="no"
  connected="no"
  if [[ $installed == yes && $running == no ]]; then
    registered="unknown (service not running)"
  elif [[ $installed == yes ]]; then
    registered=$(yes_no is_registered)
    connected=$(yes_no is_connected)
  elif pkg=$(package_for_arch); then
    installed="no (package for this computer: $pkg)"
  else
    installed="no (no package for this processor: $(uname -m))"
  fi

  say "Cloudflare WARP"
  say "  Installed:        $installed"
  say "  Service running:  $running"
  say "  Registered:       $registered"
  say "  Connected:        $connected"

  [[ $installed == yes && $running == yes && $registered == yes ]]
}

install_package() {
  local pkg="$1"
  step "Installing $pkg from the AUR..."
  if command -v omarchy-pkg-aur-add >/dev/null 2>&1; then
    omarchy-pkg-aur-add "$pkg" || fail "Could not install $pkg."
  elif command -v yay >/dev/null 2>&1; then
    yay -S --needed "$pkg" || fail "Could not install $pkg."
  else
    fail "Installing $pkg needs yay (an AUR helper), which was not found."
  fi
  hash -r
  is_installed || fail "$pkg was installed, but warp-cli is still not found."
}

start_service() {
  if service_running; then
    say "The warp-svc service is already running."
  else
    step "Starting the warp-svc service (now and at every boot)..."
    sudo systemctl enable --now "$SERVICE" || fail "Could not start warp-svc."
  fi

  local waited=0
  until daemon_answers; do
    if (( waited >= DAEMON_WAIT_SECONDS )); then
      fail "warp-svc is not answering after ${DAEMON_WAIT_SECONDS} seconds. See: systemctl status warp-svc"
    fi
    if (( waited == 0 )); then say "Waiting for warp-svc to answer..."; fi
    sleep 1
    waited=$((waited + 1))
  done
}

register_device() {
  if is_registered; then
    say "This device is already registered."
    return 0
  fi
  step "Register this device"
  say "Registering creates a free WARP account for this computer."
  say "It means you accept Cloudflare's WARP terms of service:"
  say "  $TERMS_URL"
  if ! ask "Accept the terms and register this device?"; then
    say "Not registered. Nothing else was changed. Run this again when you are ready."
    exit 0
  fi
  warp-cli --accept-tos registration new || fail "Registration failed."
}

connect_now() {
  if is_connected; then
    say "WARP is connected."
  elif ask "Connect WARP now?"; then
    warp-cli --accept-tos connect || fail "Could not connect WARP."
  else
    say "Not connected. Right-click the cloud icon in the bar to connect later."
  fi
}

setup() {
  if (( EUID == 0 )); then
    fail "Run this as your normal user, not with sudo. It asks for your password when it needs it."
  fi

  local pkg=""
  local -a plan=()
  if ! is_installed; then
    pkg=$(package_for_arch) ||
      fail "Cloudflare WARP has no Linux package for this processor ($(uname -m)). Only x86_64 and aarch64 are supported."
    plan+=("install $pkg from the AUR (asks for your password)")
  fi
  if [[ -n $pkg ]] || ! service_running; then
    plan+=("start the warp-svc service now and at every boot (asks for your password)")
  fi
  if [[ -n $pkg ]] || ! daemon_answers || ! is_registered; then
    plan+=("register this device with Cloudflare, if it is not yet (asks first)")
  fi

  if (( ${#plan[@]} == 0 )); then
    say "Cloudflare WARP is installed, running and registered."
  else
    say "This sets up Cloudflare WARP for the bar icon. It will:"
    local item
    for item in "${plan[@]}"; do say "  - $item"; done
    say "Using WARP means accepting Cloudflare's terms: $TERMS_URL"
    say ""
    if ! ask "Continue?"; then
      say "Nothing was changed."
      exit 0
    fi
    if [[ -n $pkg ]]; then install_package "$pkg"; fi
    start_service
    register_device
  fi

  connect_now
  step "All set. The cloud icon in the bar updates by itself in a few seconds."
}

case "${1:-}" in
  "") setup ;;
  --check) check ;;
  -h | --help) usage ;;
  *)
    usage >&2
    exit 2
    ;;
esac
