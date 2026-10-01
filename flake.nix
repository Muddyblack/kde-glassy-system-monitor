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
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # The viewer alone does not include the desktop containment's QML
          # plugins. Wrap its dependencies from the same nixpkgs revision.
          viewRuntime = pkgs.stdenvNoCC.mkDerivation {
            name = "glassy-plasmoidviewer";
            dontUnpack = true;
            nativeBuildInputs = [ pkgs.kdePackages.wrapQtAppsHook ];
            buildInputs = with pkgs.kdePackages; [
              qtbase plasma-sdk plasma-desktop plasma-workspace kdeclarative
              plasma-integration breeze qqc2-desktop-style
            ];
            dontWrapQtApps = true;
            installPhase = ''
              mkdir -p "$out/bin"
              cat > "$out/bin/glassy-view" <<'EOF'
              #!${pkgs.runtimeShell}
              exec ${pkgs.kdePackages.plasma-sdk}/bin/plasmoidviewer -a "$PWD/package" -f "''${1:-planar}"
              EOF
              chmod +x "$out/bin/glassy-view"
            '';
            postFixup = ''
              wrapQtApp "$out/bin/glassy-view" \
                --prefix XDG_DATA_DIRS : "${pkgs.kdePackages.plasma-desktop}/share:${pkgs.kdePackages.plasma-workspace}/share"
            '';
          };
        in {
          view = {
            type = "app";
            program = toString (pkgs.writeShellScript "view" ''
              # Clear session/dev-shell paths before the Qt wrapper supplies
              # this build's dependencies. Qt private APIs differ by patch release.
              unset QML_IMPORT_PATH QML2_IMPORT_PATH NIXPKGS_QT6_QML_IMPORT_PATH
              unset NIXPKGS_QML_SEARCH_PATHS QT_PLUGIN_PATH QT_ADDITIONAL_PACKAGES_PREFIX_PATH
              unset LD_LIBRARY_PATH QT_STYLE_OVERRIDE QT_QUICK_CONTROLS_CONF
              unset QT_QUICK_CONTROLS_FALLBACK_STYLE
              # Read the user's KDE palette through a matching platform plugin.
              # Use bundled styles rather than a session style from another Qt.
              export QT_STYLE_OVERRIDE=Breeze
              export QT_QUICK_CONTROLS_STYLE=org.kde.desktop
              export QT_QPA_PLATFORMTHEME=kde
              exec ${viewRuntime}/bin/glassy-view "$@"
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
