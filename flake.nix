{
  description = "MabOS's own Nix packages, and the binary cache they are built into";

  # Each package is pinned here; MabOS takes them as they are (it doesn't override these inputs),
  # so its machines get exactly what the cache holds
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Millennium, Steam's modding framework: its own Nix package. Its Nix files build an older
    # commit than the tag, so the tag's own source is a separate input
    millennium = {
      url = "github:SteamClientHomebrew/Millennium/v3.6.3?dir=packages/nix";
      inputs.millennium-src.follows = "millennium-src";
    };
    millennium-src = {
      url = "github:SteamClientHomebrew/Millennium/v3.6.3";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, millennium, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      packages = {
        strata = pkgs.callPackage ./pkgs/strata { };
        helium = pkgs.callPackage ./pkgs/helium { };
        freshgram = pkgs.callPackage ./pkgs/freshgram { };
        millennium = millennium.packages.${system}.millennium;
      };
    in
    {
      packages.${system} = packages // {
        # What the workflow builds into the cache
        cache = pkgs.linkFarmFromDrvs "mabos-packages" (builtins.attrValues packages);
      };

      # For MabOS's pkgs: the packages, and the system's Steam with Millennium in it
      overlays.default = final: prev: packages // {
        millennium-steam = final.callPackage "${millennium}/steam.nix" {
          inherit (packages) millennium;
        };
      };
    };
}
