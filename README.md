# Cloudflare WARP for the Omarchy bar

An [Omarchy](https://omarchy.org/) shell plugin that puts Cloudflare WARP in the top bar.

- **Cloud icon** in the bar: bright when connected, dimmed with a slash when off, pulsing while it switches, and a small red dot while WARP still needs setting up.
- **Left click** opens a panel styled like the built-in Tailscale panel:
  - on/off switch and status line (for example "Connected via MAA · IN")
  - mode picker: WARP, WARP + DoH, 1.1.1.1 only, Proxy
  - connection details: location, public IP (with a copy button), protocol, account type
- **Right click** turns WARP on or off. **Middle click** refreshes.
- **Keys in the panel:** `j`/`k` or arrows to move, `Enter` to choose, `t` toggle, `r` refresh, `c` copy IP, `Esc` close.

## Requirements

- Omarchy Quattro (the Quickshell-based `omarchy-shell`).
- An x86_64 or aarch64 computer. The plugin can install Cloudflare WARP for you (see below).

The plugin calls `warp-cli` with `--accept-tos`, so using it means you accept Cloudflare's WARP [terms of service](https://www.cloudflare.com/application/terms/).

## Install

```sh
omarchy plugin add https://github.com/shikharish/omarchy-warp.git --enable
```

If Cloudflare WARP is not set up yet, the cloud icon shows a red dot. Click it, then click **Install Cloudflare WARP**
(or **Start WARP service** / **Register this device**, whichever step is missing). A terminal opens and walks you through it.
You can also run the same script yourself:

```sh
~/.config/omarchy/plugins/shikhar.warp/install-warp.sh          # set up WARP
~/.config/omarchy/plugins/shikhar.warp/install-warp.sh --check  # only show what is set up
```

The icon switches to normal by itself once setup is done; no shell restart needed.

To move the icon, for example next to the network icon:

```sh
omarchy bar move shikhar.warp --section right
```

### What the setup script does

It lists the steps it will take and asks before starting. Each step is skipped when already done, so running it again is safe.

1. Installs the WARP client from the AUR if `warp-cli` is missing, with Omarchy's AUR helper (`omarchy-pkg-aur-add`, or `yay` if that is not there):
   `cloudflare-warp-bin` on x86_64, `cloudflare-warp-nox-bin` on aarch64. Other processors are not supported. Asks for your password.
2. Starts the `warp-svc` service now and at every boot (`sudo systemctl enable --now warp-svc`) if it is not running. Asks for your password.
3. Registers this device (`warp-cli registration new`), which accepts Cloudflare's terms. It shows the terms link and asks first.
4. Offers to connect.

It never downloads and runs scripts, and it adds no sudo rules.

## Check it

```sh
omarchy-shell shikhar.warp status   # Connected / Disconnected / NotInstalled / ServiceDown / Unregistered / ...
omarchy-shell shikhar.warp open     # opens the panel
omarchy-shell shikhar.warp toggleWarp
omarchy-shell shikhar.warp install  # opens the setup terminal
```

## What it runs

- Only `warp-cli` (status, settings, registration, connect/disconnect, mode), always with fixed arguments and never with outside text put into a shell command.
- When you click a setup button (or call `install`): `install-warp.sh` from the plugin folder, in Omarchy's floating terminal.
- While the panel is open, one capped request (5 s timeout, 4 KB limit) to `https://www.cloudflare.com/cdn-cgi/trace` to show your public IP and location.
- `wl-copy` and `notify-send` when you copy the IP.

All text from those commands is shown as plain text.

Setting: `refreshIntervalSec` (2 to 300, default 5) in the widget's bar settings.

## Troubleshooting

- **Panel opens in the top-left corner instead of under the icon:** you are probably using a cloned or third-party bar that is older than your Omarchy install. Switch back to the built-in `omarchy.bar`, or update your bar clone.
- **Panel says Cloudflare WARP is not installed, but it is:** make sure `warp-cli` is on `PATH` for the shell, then run `install-warp.sh --check`.

## Remove

```sh
omarchy plugin remove shikhar.warp
```

To also remove Cloudflare WARP itself:

```sh
sudo systemctl disable --now warp-svc
yay -Rns cloudflare-warp-bin    # cloudflare-warp-nox-bin on aarch64
```

## License

MIT, see [LICENSE](LICENSE).
