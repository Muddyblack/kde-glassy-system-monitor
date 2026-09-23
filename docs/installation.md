# Installation

## Requirements

| Dependency | Notes |
|---|---|
| KDE Plasma 6.2+ (Qt 6.7+) | Per-corner card radii use Qt 6.7's `Rectangle` corners |
| `plasma5support` | The `executable` DataEngine used for ping and the fallback stats |
| `ping` (iputils) | Standard on every distro |

Optional; the widget works without them:

| Tool | Enables |
|---|---|
| `ksystemstats` + `libksysguard` | CPU / memory / network / disk with no polling of our own. Ships with Plasma; without it the widget reads `/proc` itself |
| `nvidia-smi` | NVIDIA GPU utilization, encode / decode, VRAM |
| `sensors` (lm-sensors) | Temperature sensors |
| `iwgetid` / `iw` / `nmcli` | SSID on the `/proc` fallback path |
| `mmdblookup` + a GeoIP database | Countries and owners in the network window ([details](network.md#countries-and-owners-geoip)) |
| `wireshark` / `tshark` | Open Wireshark from the network window; learn host names from a short capture ([details](network.md#wireshark)) |

## KDE Plasma

From the [KDE Store](https://www.opendesktop.org/p/2360341), or from source:

```bash
git clone https://github.com/Muddyblack/kde-glassy-system-monitor.git
cd kde-glassy-system-monitor
kpackagetool6 -t Plasma/Applet -i package   # -u to update
```

Then right-click the desktop → *Add Widgets* → **Glassy System Monitor**. To remove:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.glassySystemMonitor
```

## NixOS (flake)

```nix
{
  inputs.glassy.url = "github:Muddyblack/kde-glassy-system-monitor";

  outputs = { nixpkgs, glassy, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      modules = [
        glassy.nixosModules.default        # or glassy.homeManagerModules.default
        { programs.glassy-system-monitor = { enable = true; geoip = true; }; }
      ];
    };
  };
}
```

Or just the package: `glassy.packages.${pkgs.system}.default`.

## Hyprland (Quickshell)

The same widget runs as a desktop layer on Hyprland (or any compositor with wlr-layer-shell)
through [Quickshell](https://quickshell.outfoxxed.me/), with the same studio:

```bash
make view-hyprland      # run it (Ctrl+C stops)
make settings-hyprland  # open the studio of the running widget
make network-hyprland   # open the network window
```

Defaults go in [`shell.qml`](../shell.qml) under their Plasma names; the studio's Apply saves your
changes to `~/.config/glassy-system-monitor/hyprland.json`. Placement (screen, side, height,
margin, width, layer) is in the studio's Layout tab. For a bar, put
[`hyprland/MonitorPill.qml`](../hyprland/MonitorPill.qml) in your Quickshell bar.
