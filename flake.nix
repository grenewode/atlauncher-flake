{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }: {
    overlays.default = import ./overlay.nix;
    hmModules.default = import ./hm-module.nix;
  } // (flake-utils.lib.eachDefaultSystem (system:
    let pkgs = import nixpkgs {
      overlays = [ self.overlays.default ];
      inherit system;
    }; in
    {
      packages.default = pkgs.atlauncher;
    }));
}
