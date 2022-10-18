{ config, lib, pkgs, ... }: {
  options.programs.atlauncher = {
    enable = lib.mkEnableOption "Enable ATLauncher for Minecraft";

    package = lib.mkOption {
      description = "Package providing ATLauncher";
      type = lib.types.package;
      default = pkgs.atlauncher;
    };

    packageWrapped = lib.mkOption {
      description = "ATLauncher with arguments to make it XDG friendly";
      type = lib.types.package;
    };
  };

  config = lib.mkIf (config.programs.atlauncher.enable) {
    home.packages = [ config.programs.atlauncher.packageWrapped ];

    programs.atlauncher.packageWrapped = pkgs.runCommand "atlauncher-wrapped"
      {
        buildInputs = [ pkgs.makeWrapper ];
      } ''
      mkdir $out
      ln -s ${config.programs.atlauncher.package}/share $out/share
      mkdir $out/bin
      makeWrapper ${config.programs.atlauncher.package}/bin/atlauncher $out/bin/atlauncher \
          --add-flags '--working-dir "''${XDG_DATA_HOME-${config.xdg.dataHome}}/atlauncher"'
    ''
    ;

    nixpkgs.overlays = [
      (import ./overlay.nix)
    ];
  };
}


