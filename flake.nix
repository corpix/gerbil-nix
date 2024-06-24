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

        gambit-static = callPackage ./gambit.nix {
          enableShared = false;
          enableOpenssl = false;
        };
        gambit-shared = callPackage ./gambit.nix { enableShared = true; };
        gerbil-static = callPackage ./gerbil.nix {
          enableShared = false;
          gambit-git = gambit-static;
          zlib = pkgs.zlib.override { shared = false; static = true; };
          openssl = pkgs.openssl.override { static = true; };
          sqlite = pkgs.sqlite.overrideAttrs (super: {
            configureFlags = super.configureFlags ++ [
              "--enable-static"
              "--disable-shared"
            ];
          });
        };
        gerbil-shared = callPackage ./gerbil.nix {
          enableShared = true;
          gambit-git = gambit-shared;
        };
      in {
        packages.default = gerbil-static;

        packages.gambit-static = gambit-static;
        packages.gambit-shared = gambit-shared;
        packages.gerbil-static = gerbil-static;
        packages.gerbil-shared = gerbil-shared;

        stdenv.default = callPackage ./stdenv.nix { gerbil = gerbil-static; };
        stdenv.static = callPackage ./stdenv.nix { gerbil = gerbil-static; };
        stdenv.shared = callPackage ./stdenv.nix { gerbil = gerbil-shared; };

        devShells.default = pkgs.mkShell {
          name = "gerbil";
          packages = attrValues {
            inherit (pkgs)
              coreutils
              gnumake
              gnused
              git
              jq

              zlib
              openssl
              sqlite

              gerbil-git
              gambit-git
            ;
          };
          shellHook = ''
            export NIX_BUILD_CORES=3
            export NIX_PATH=nixpkgs-overlays=$(pwd)/overlay:$NIX_PATH
          '';
        };
      };
    in (flake-utils.lib.eachDefaultSystem mkArch) // {
      overlays.default = import ./overlay;
    };
}
