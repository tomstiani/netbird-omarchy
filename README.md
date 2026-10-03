<img width="580" height="737" alt="screenshot-2026-10-03_11-29-14" src="https://github.com/user-attachments/assets/9bd93baf-3afc-4606-93f0-acb37e7a1f89" />

# NetBird for Omarchy

**Your private network, one glance away.**

Bring your NetBird mesh into the Omarchy bar: see whether this machine is connected, find the devices you care about, and copy a peer's IP with one click. The Quickshell popup stays out of your way until you need it—no separate tray app, no second shell process, and no wall of generated proxy names.

- **Know what's happening.** Connection state, your NetBird address, total peers, and active links at a glance.
- **Find a machine fast.** Human-readable device names up front; generated proxies grouped and collapsed by default.
- **Get there in a click.** Hover a peer for the copy affordance; click anywhere on its row to copy its NetBird IP.
- **Stay in control.** Sign in, reconnect, disconnect, or refresh peer status from the popup.
- **Bring your own network.** Works with NetBird Cloud or a self-hosted management server; no endpoint is baked into the plugin.

> **Already using NetBird?** Install the widget, add it to the bar, and you're ready. It reads your existing local NetBird profile.

## Quick guide

### 1. Have NetBird running

Install the **NetBird CLI and daemon** for your system. On Omarchy/Arch, one option is:

```bash
omarchy pkg aur add netbird-bin
sudo systemctl enable --now netbird@default.service
```

Other distributions or package variants may use a different service name. Follow [NetBird's installation guide](https://docs.netbird.io/get-started/install) for your platform. The widget never installs or starts the daemon for you.

### 2. Install the widget

Install from the [GitHub repository](https://github.com/tomstiani/netbird-omarchy):

```bash
omarchy plugin add https://github.com/tomstiani/netbird-omarchy.git --enable
```

Omarchy installs the checkout under `~/.config/omarchy/plugins/tomstiani.netbird/`. You can also place this directory there manually and run `omarchy plugin enable tomstiani.netbird`. The default bar placement is **right**.

> Plugins run as code inside `omarchy-shell` with your user permissions. Review a repository before installing it.

### 3. Connect

Click the NetBird icon in the bar:

- **NeedsLogin:** click **Sign in**. Authentication opens in a terminal; follow the NetBird prompts there.
- **Disconnected:** click **Connect**. An existing profile reconnects in the background.
- **Connected:** the header offers **Disconnect**. This disconnects NetBird on the machine, not just the widget.

For a **self-hosted server**, set `managementUrl` as shown below *before* signing in. For NetBird Cloud, leave it empty.

### 4. Use the peer list

**Devices** are listed by name. **Proxies** (when present) are collapsed below them; click the Proxies heading to expand it. Click a peer row to copy its NetBird IP. The small refresh icon at the far right of **PEERS** fetches status immediately; the widget also polls automatically.

## Configuration

Settings are inline on this widget's entry in `~/.config/omarchy/shell.json`, under `bar.layout.right` (or whichever section you placed it in):

```json
{
  "id": "tomstiani.netbird",
  "managementUrl": "https://netbird.example.com",
  "daemonAddress": ""
}
```

| Setting | Default | Meaning |
| --- | --- | --- |
| `managementUrl` | `""` | Optional management server URL passed to `netbird up`. Empty uses the existing profile or NetBird's default server. For self-hosting, use your management endpoint, not necessarily the dashboard URL. |
| `daemonAddress` | `""` | Optional NetBird daemon address, e.g. `unix:///run/netbird/default.sock`. Empty lets the NetBird CLI discover its daemon. |

You can omit either setting when you don't need it. The plugin stores **no setup key or credentials**. To use a nonstandard daemon socket, set `daemonAddress` explicitly. If you change settings while the widget is running, Omarchy reloads its shell configuration; `omarchy restart shell` will force a fresh load if needed.

### Controls

| Action | Result |
| --- | --- |
| Click bar icon | Open or close the popup |
| Sign in / Connect / Disconnect in header | Act on the current NetBird profile |
| Click a device or proxy | Copy its NetBird IP to the Wayland clipboard |
| Click Proxies heading | Expand or collapse generated proxy peers |
| Refresh icon beside PEERS | Read `netbird status --json` now |
| `r` / `c` / `d` in popup | Refresh / connect (or sign in) / disconnect |
| `Esc` | Close the popup |

The widget polls status every **5 seconds while open**, and every **30 seconds while closed**. Refresh only re-reads status; it does not reconnect or change settings. An **active link** is a currently established peer connection, not the number of peers registered to your network: an `Idle` peer is not necessarily offline.

## Requirements and troubleshooting

- Omarchy with the Quickshell-based plugin shell and bar widgets.
- `netbird` CLI with a working local NetBird daemon.
- `wl-copy` from `wl-clipboard` for click-to-copy.
- A terminal available through `omarchy launch terminal` for interactive sign-in.

If the widget says **Unavailable**, first check NetBird itself:

```bash
netbird status --json
systemctl status netbird@default.service  # for the Arch service shown above
```

If your CLI needs a custom socket, set `daemonAddress` in the widget; you can check it with `netbird --daemon-addr unix:///path/to/netbird.sock status --json`. For a missing bar widget or a broken popup, validate the folder with `omarchy plugin validate ~/.config/omarchy/plugins/tomstiani.netbird` and try `omarchy restart shell`.

## Remove

```bash
omarchy plugin disable tomstiani.netbird
omarchy plugin remove tomstiani.netbird
```

Removing the plugin does **not** uninstall NetBird, disconnect the daemon, or delete your NetBird profile.

## License

MIT. See [LICENSE](LICENSE).
