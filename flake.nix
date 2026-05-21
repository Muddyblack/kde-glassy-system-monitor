{
  description = "KDE Plasma 6 glassy real-time system performance and network monitor widget";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      forAllSystems = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f system);
      metadata = builtins.fromJSON (builtins.readFile ./package/metadata.json);
    in {
      packages = forAllSystems (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          default = pkgs.stdenvNoCC.mkDerivation {
            pname = "glassy-system-monitor";
            version = metadata.KPlugin.Version;
            src = ./package;

            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              runHook preInstall
              root=$out/share/plasma/plasmoids/org.muddyblack.glassySystemMonitor
              mkdir -p "$root"
              cp -r . "$root/"
              runHook postInstall
            '';

            meta = with pkgs.lib; {
              description = "KDE Plasma 6 glassy real-time system performance and network monitor widget";
              license = licenses.mit;
              platforms = platforms.linux;
              homepage = "https://github.com/Muddyblack/kde-glassy-system-monitor";
            };
          };
        });
    };
}
