{
  inputs = {
    nixpkgs.url = "tarball+https://git.tatikoma.dev/corpix/nixpkgs/archive/v2024-05-09.609610.tar.gz";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (arch:
        let
          pkgs = nixpkgs.legacyPackages.${arch}.pkgs;

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
            ;
          };
          static = callPackage ./package.nix { enableShared = false; };
          shared = callPackage ./package.nix { enableShared = true; };
        in {
          packages.default = static;
          packages.static = static;
          packages.shared = shared;
          devShells.default = pkgs.mkShell {
            name = "gerbil";
            packages = packages ++ [static];
          };
        });
}
