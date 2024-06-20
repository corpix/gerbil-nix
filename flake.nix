{
  inputs = {
    nixpkgs.url = "tarball+https://git.tatikoma.dev/corpix/nixpkgs/archive/v2024-05-29.632320.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      mkArch = arch: let
        pkgs = import nixpkgs {
          system = arch;
          overlays = [self.overlays.default];
        };

        inherit (pkgs)
          callPackage
          writeScript
          stdenv
        ;
        inherit (pkgs.lib)
          attrValues
          filter
        ;

        packages = attrValues {
          inherit (pkgs)
            coreutils
            gnumake
            gnused
            jq

            gerbil-git
          ;
        };
        static = callPackage ./gerbil.nix { enableShared = false; };
        shared = callPackage ./gerbil.nix { enableShared = true; };
      in {
        packages.default = static;
        packages.static = static;
        packages.shared = shared;
        stdenv.default = callPackage ./stdenv.nix { gerbil = static; };
        stdenv.static = callPackage ./stdenv.nix { gerbil = static; };
        stdenv.shared = callPackage ./stdenv.nix { gerbil = shared; };
        devShells.default = pkgs.mkShell {
          name = "gerbil";
          inherit packages;
        };
      };
    in (flake-utils.lib.eachDefaultSystem mkArch) // {
      overlays.default = _: prev: {
        gerbil-git = self.packages.${prev.stdenv.hostPlatform.system}.default;
      };
    };
}
