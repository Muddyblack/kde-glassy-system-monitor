{
  description = "Glassy system monitor for KDE Plasma 6 and Hyprland (Quickshell)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f system);
      metadata = builtins.fromJSON (builtins.readFile ./package/metadata.json);
    in {
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "glassy-system-monitor";
            version = metadata.KPlugin.Version;
            src = ./package;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              
              # Install plasmoid package
              root=$out/share/plasma/plasmoids/org.muddyblack.glassySystemMonitor
              mkdir -p "$root"
              cp -r . "$root/"

              # Register icon in hicolor theme so Plasma Widget Explorer picks it up
              mkdir -p "$out/share/icons/hicolor/256x256/apps"
              cp icon.png "$out/share/icons/hicolor/256x256/apps/org.muddyblack.glassySystemMonitor.png"

              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "KDE Plasma 6 glassy real-time system performance and network monitor widget";
              license = licenses.gpl3Plus;
              platforms = platforms.linux;
              homepage = "https://github.com/Muddyblack/kde-glassy-system-monitor";
            };
          };

          # Countries and owners in the network window: mmdblookup plus db-ip's
          # free Lite databases from nixpkgs (updated there monthly).
          geoip = pkgs.symlinkJoin {
            name = "glassy-system-monitor-geoip";
            paths = [ pkgs.libmaxminddb pkgs.dbip-country-lite pkgs.dbip-asn-lite ];
          };
        });

      # NixOS: programs.glassy-system-monitor = { enable = true; geoip = true; };
      nixosModules.default = { config, lib, pkgs, ... }:
        let cfg = config.programs.glassy-system-monitor;
        in {
          options.programs.glassy-system-monitor = {
            enable = lib.mkEnableOption "the Glassy System Monitor widget";
            geoip = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Install mmdblookup and the db-ip Lite databases so the network window shows countries and owners (all local).";
            };
          };
          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ]
              ++ lib.optionals cfg.geoip [ pkgs.libmaxminddb pkgs.dbip-country-lite pkgs.dbip-asn-lite ];
            environment.pathsToLink = lib.mkIf cfg.geoip [ "/share/dbip" ];
            environment.sessionVariables = lib.mkIf cfg.geoip {
              GLASSY_GEOIP_COUNTRY = pkgs.dbip-country-lite.mmdb;
              GLASSY_GEOIP_ASN = pkgs.dbip-asn-lite.mmdb;
            };
          };
        };

      # home-manager: the same, for one user.
      homeManagerModules.default = { config, lib, pkgs, ... }:
        let cfg = config.programs.glassy-system-monitor;
        in {
          options.programs.glassy-system-monitor = {
            enable = lib.mkEnableOption "the Glassy System Monitor widget";
            geoip = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Install mmdblookup and the db-ip Lite databases so the network window shows countries and owners (all local).";
            };
          };
          config = lib.mkIf cfg.enable {
            home.packages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.default ]
              ++ lib.optionals cfg.geoip [ pkgs.libmaxminddb pkgs.dbip-country-lite pkgs.dbip-asn-lite ];
            home.sessionVariables = lib.mkIf cfg.geoip {
              GLASSY_GEOIP_COUNTRY = pkgs.dbip-country-lite.mmdb;
              GLASSY_GEOIP_ASN = pkgs.dbip-asn-lite.mmdb;
            };
          };
        };

      apps = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          view = {
            type = "app";
            program = toString (pkgs.writeShellScript "view" ''
              export PATH=${pkgs.lib.makeBinPath [ pkgs.kdePackages.plasma-sdk pkgs.kdePackages.plasma-desktop ]}:"$PATH"
              exec plasmoidviewer \
                -a "$PWD/package" -f "''${1:-planar}"
            '');
          };
          view-hyprland = {
            type = "app";
            program = toString (pkgs.writeShellScript "view-hyprland" ''
              export PATH=${pkgs.lib.makeBinPath [ pkgs.quickshell pkgs.lm_sensors pkgs.iputils pkgs.iproute2 pkgs.libmaxminddb ]}:"$PATH"
              export GLASSY_GEOIP_COUNTRY=''${GLASSY_GEOIP_COUNTRY:-${pkgs.dbip-country-lite.mmdb}}
              export GLASSY_GEOIP_ASN=''${GLASSY_GEOIP_ASN:-${pkgs.dbip-asn-lite.mmdb}}
              exec bash "$PWD/hyprland/run.sh" "$@"
            '');
          };
          pack = {
            type = "app";
            program = toString (pkgs.writeShellScript "pack" ''
              set -euo pipefail
              here="$PWD"
              ver="$(grep -oE '"Version":[[:space:]]*"[^"]+"' "$here/package/metadata.json" | head -1 | sed -E 's/.*"([^"]+)"$/\1/')"
              name="$(basename "$here")"
              out="$here/$name-$ver.plasmoid"
              rm -f "$out"
              (cd "$here/package" && ${pkgs.zip}/bin/zip -r "$out" . -x '*.swp' '*~')
              echo "wrote $out"
            '');
          };
        });

      devShells = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system};
        in {
          default = pkgs.mkShell {
            name = "glassy-system-monitor-dev";
            packages = with pkgs; [
              qt6.qtdeclarative
              qt6.qtshadertools
              qt6.qtsvg
              kdePackages.kpackage
              kdePackages.plasma-sdk
              kdePackages.plasma-desktop
              pre-commit
              zip
            ];
            # The pre-commit hooks invoke their tools through `nix develop`, which
            # runs this shellHook first. Re-installing the hooks from inside a
            # hook run deadlocks on pre-commit's own cache lock, so skip setup
            # when pre-commit is what entered the shell (it exports PRE_COMMIT=1).
            shellHook = ''
              if [ -z "$PRE_COMMIT" ]; then
                pre-commit install -f --install-hooks
                echo "glassy-system-monitor dev shell ready"
                echo "  make help        — list targets (view, view-hyprland, parity, benchmark, test, docs, pack, tag)"
              fi
            '';
          };
        });
    };
}
