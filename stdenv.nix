{ stdenv, writeText, pkg-config, gerbil, ... }: let
  inherit (builtins)
    removeAttrs
  ;
in {
  mkGerbilPackage = let
    reservedAttrs = ["name" "version" "src" "propagatedBuildInputs" "meta"];
  in { name, version ? "", src, propagatedBuildInputs ? [], ... } @ attrs:
    stdenv.mkDerivation ({
      inherit
        name
        version
        src
      ;

      setupHook = writeText "setup-hook.sh" ''
        addGerbilRepositoryPath() {
          addToSearchPathWithCustomDelimiter : GERBIL_LOADPATH "$1/gerbil/lib"
        }

        addEnvHooks "$hostOffset" addGerbilRepositoryPath
      '';
      nativeBuildInputs = [ pkg-config ];
      propagatedBuildInputs = [ gerbil ] ++ propagatedBuildInputs;

      configurePhase = ''
        export HOME=$(pwd)
      '';
      meta = {
        inherit (gerbil.meta) platforms;
      } // attrs.meta or {};
    } // removeAttrs attrs reservedAttrs);
}
