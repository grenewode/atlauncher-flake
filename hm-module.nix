{ config, lib, pkgs, ... }: {
  options.programs.atlauncher = {
    enable = lib.mkEnableOption "Enable ATLauncher for Minecraft";

    package = lib.mkOption {
      description = "Package providing ATLauncher";
      type = lib.types.package;
      default = pkgs.atlauncher;
    };
  };

  config = lib.mkIf (config.programs.atlauncher.enable) {
    home.packages = [ config.programs.atlauncher.package ];

    nixpkgs.overlays = [
      (import ./overlay.nix)
    ];
  };
}
