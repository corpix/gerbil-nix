{
  inputs = {
    gerbil.url = "git+file:../";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, gerbil }:
    flake-utils.lib.eachDefaultSystem
      (arch: let
        pkgs = import gerbil.inputs.nixpkgs { system = arch; };
        mkGerbilPackageTest = flavor: gerbil.stdenv.${arch}.${flavor}.mkGerbilPackage {
          name = "mk-gerbil-package-test";
          version = "unstable";
          src = ./mk-gerbil-package/.;
          buildPhase = ''
            gxc hello.ss
          '';
          installPhase = ''
            mkdir -p $out/gerbil
            mv .gerbil/lib $out/gerbil
          '';
        };
        mkShell = flavor: pkgs.mkShell {
          name = "gerbil";
          packages = [
            (mkGerbilPackageTest flavor)
            gerbil.packages.${arch}.${flavor}
          ];
        };
      in {
        packages.mkGerbilPackageTestStatic = mkGerbilPackageTest "static";
        devShells.static = mkShell "static";
      });
}
