# Cloudflare WARP for the Omarchy bar

An [Omarchy](https://omarchy.org/) shell plugin that puts Cloudflare WARP in the top bar.

- **Cloud icon** in the bar: bright when connected, dimmed with a slash when off, pulsing while it switches.
- **Left click** opens a panel styled like the built-in Tailscale panel:
  - on/off switch and status line (for example "Connected via MAA · IN")
  - mode picker: WARP, WARP + DoH, 1.1.1.1 only, Proxy
  - connection details: location, public IP (with a copy button), protocol, account type
- **Right click** turns WARP on or off. **Middle click** refreshes.
- **Keys in the panel:** `j`/`k` or arrows to move, `Enter` to choose, `t` toggle, `r` refresh, `c` copy IP, `Esc` close.

## Requirements

- Omarchy Quattro (the Quickshell-based `omarchy-shell`).
- The Cloudflare WARP client installed (`warp-cli` on `PATH`), its `warp-svc` service running, and the device registered (`warp-cli registration new`).

The plugin calls `warp-cli` with `--accept-tos`, so using it means you accept Cloudflare's WARP terms of service.

## Install

```sh
omarchy plugin add https://github.com/shikharish/omarchy-warp.git --enable
```

Then place it where you like, for example next to the network icon:

```sh
omarchy bar move shikhar.warp --section right
```

If `omarchy-shell shikhar.warp status` says the target is not found right after installing, run `omarchy restart shell` once.

## Check it

```sh
omarchy-shell shikhar.warp status   # prints Connected / Disconnected / ...
omarchy-shell shikhar.warp open     # opens the panel
omarchy-shell shikhar.warp toggleWarp
```

## What it runs

- Only `warp-cli` (status, settings, registration, connect/disconnect, mode), always as an argument list, never through a shell.
- While the panel is open, one capped request (5 s timeout, 4 KB limit) to `https://www.cloudflare.com/cdn-cgi/trace` to show your public IP and location.
- `wl-copy` and `notify-send` when you copy the IP.

All text from those commands is shown as plain text.

Setting: `refreshIntervalSec` (2 to 300, default 5) in the widget's bar settings.

## Troubleshooting

- **Panel opens in the top-left corner instead of under the icon:** you are probably using a cloned or third-party bar that is older than your Omarchy install. Switch back to the built-in `omarchy.bar`, or update your bar clone.
- **Icon shows "not installed":** `warp-cli` is not on `PATH` for the shell.

## Remove

```sh
omarchy plugin remove shikhar.warp
```

## License

MIT, see [LICENSE](LICENSE).
