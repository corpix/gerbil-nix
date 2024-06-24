{ pkgs, lib, gccStdenv, coreutils
, openssl, zlib, sqlite, pkg-config
, version, src
, gambit-git
, gerbil-git-version
, enableShared
}:

let
  stdenv = gccStdenv;

  inherit (pkgs)
    writeText
  ;
  inherit (lib)
    optionalString
    concatStringsSep
    getLib
    licenses
    platforms
  ;
in stdenv.mkDerivation rec {
  pname = "gerbil";
  inherit version;
  inherit src;

  nativeBuildInputs = [pkg-config];
  buildInputs = [
    gambit-git
    zlib
    openssl
    sqlite
  ];

  setupHook = writeText "setup-hook.sh" ''
    addGerbilHome() {
      export GERBIL_HOME="@out@/gerbil"
    }

    addEnvHooks "$hostOffset" addGerbilHome
  '';

  patches = [
    ./patch/0000-gambit-output-prefix-gerbil.patch
    ./patch/0001-gerbil-gambit-pkg.patch
  ];
  patchFlags = ["-p0"];

  postPatch = ''
    patchShebangs .
    grep -Fl '#!/usr/bin/env' `find . -type f -executable` | while read f
    do
      substituteInPlace "$f" --replace-fail '#!/usr/bin/env' '#!${coreutils}/bin/env'
    done
    cat > MANIFEST <<EOF
    gerbil_stamp_version=v${gerbil-git-version}
    EOF

    # ~~ will point to Gambit, while we need "actual" Gerbil home dir
    substituteInPlace "src/gerbil/runtime/system.ss" --replace-fail '(path-expand "~~")' "\"$out/gerbil\""
  '';

  configureFlags = [
    "--prefix=$out/gerbil"
    "--enable-zlib"
    "--enable-sqlite"
    "--enable-march=" # Avoid non-portable invalid instructions. Use =native if local build only.
    (if enableShared then "--enable-shared" else "--disable-shared")
  ];

  configurePhase = ''
    export GAMBIT_PKG=${gambit-git}
    env
    ./configure ${concatStringsSep " " configureFlags}
  '';

  extraLdOptions = map (input: "-L${getLib input}/lib") buildInputs;

  buildPhase = let
    libGerbilLddFix = ''
      substituteInPlace build/lib/libgerbil.ldd \
        --replace-fail '(' '(${concatStringsSep " " (map (x: ''"${x}"'' ) extraLdOptions)}'
    '';
  in ''
    runHook preBuild

    export HOME=$PWD
    export GERBIL_BUILD_CORES=$NIX_BUILD_CORES
    export GERBIL_GXC=$PWD/bin/gxc
    export GERBIL_BASE=$PWD
    export GERBIL_PREFIX=$PWD
    export GERBIL_PATH=$PWD/lib
    export PATH=$PWD/bin:$PATH

    if [ ! -d $GERBIL_BASE/build/bin ]
    then
      mkdir -p $GERBIL_BASE/build/bin
    fi
    for bin in ${gambit-git}/bin/*
    do
      ln -s $(readlink -f $bin) $GERBIL_BASE/build/bin/$(basename $bin)
    done

    ( cd src && ./build.sh )

    ${optionalString enableShared libGerbilLddFix}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/gerbil $out/bin
    ./install.sh
    (cd $out/bin ; ln -s ../gerbil/bin/* .)
    runHook postInstall
  '' + optionalString (stdenv.isDarwin && enableShared) ''
    libgerbil="$(realpath "$out/gerbil/lib/libgerbil.so")"
    install_name_tool -id "$libgerbil" "$libgerbil"
  '';

  dontStrip = true;

  meta = {
    description = "Gerbil Scheme";
    homepage = "https://github.com/vyzo/gerbil";
    license = licenses.lgpl21Only;
    platforms = platforms.unix;
  };
}
