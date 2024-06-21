{ pkgs, lib, gccStdenv, coreutils
, openssl, zlib, sqlite
, version, src
, gerbil-git-version
, gambit-support
, gambit-git-version
, gambit-stamp-ymd
, gambit-stamp-hms
, gambit-gambopt ? ["i8" "f8" "-8" "t8"]
  , enableShared
}:

let
  stdenv = gccStdenv;

  inherit (lib)
    optionalString
    concatStringsSep
    licenses
    platforms
  ;
in stdenv.mkDerivation rec {
  pname = "gerbil";
  inherit version;
  inherit src;

  buildInputs = [ openssl zlib sqlite ];

  postPatch = ''
    patchShebangs .
    grep -Fl '#!/usr/bin/env' `find . -type f -executable` | while read f
    do
      substituteInPlace "$f" --replace '#!/usr/bin/env' '#!${coreutils}/bin/env'
    done
    cat > MANIFEST <<EOF
    gerbil_stamp_version=v${gerbil-git-version}
    gambit_stamp_version=v${gambit-git-version}
    gambit_stamp_ymd=${gambit-stamp-ymd}
    gambit_stamp_hms=${gambit-stamp-hms}
    EOF

    export GERBIL_GCC=${gccStdenv.cc}/bin/${gccStdenv.cc.targetPrefix}gcc
  '';

  configureFlags = [
    "--prefix=$out/gerbil"
    "--enable-zlib"
    "--enable-sqlite"
    "--enable-march=" # Avoid non-portable invalid instructions. Use =native if local build only.
    (if enableShared then "--enable-shared" else "--disable-shared")
  ];

  configurePhase = ''
    export CC=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}gcc \
           CXX=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}g++ \
           CPP=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cpp \
           CXXCPP=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}cpp \
           LD=${stdenv.cc}/bin/${stdenv.cc.targetPrefix}ld \
           XMKMF=${coreutils}/bin/false
    unset CFLAGS LDFLAGS LIBS CPPFLAGS CXXFLAGS
    ./configure ${builtins.concatStringsSep " " configureFlags}
  '';

  extraLdOptions = [
      "-L${zlib}/lib"
      "-L${openssl.out}/lib"
      "-L${sqlite.out}/lib"
    ];

  buildPhase = ''
    runHook preBuild

    # gxprof testing uses $HOME/.cache/gerbil/gxc
    export HOME=$PWD
    export GERBIL_BUILD_CORES=$NIX_BUILD_CORES
    export GERBIL_GXC=$PWD/bin/gxc
    export GERBIL_BASE=$PWD
    export GERBIL_PREFIX=$PWD
    export GERBIL_PATH=$PWD/lib
    export PATH=$PWD/bin:$PATH
    export GAMBOPT="${concatStringsSep "," gambit-gambopt}"

    # Build, replacing make by build.sh
    ( cd src && ./build.sh )

  '' + (optionalString enableShared ''
    substituteInPlace build/lib/libgerbil.ldd \
      --replace '(' '(${concatStringsSep " " (map (x: ''"${x}"'' ) extraLdOptions)}'
  '') + ''
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

  meta = {
    description = "Gerbil Scheme";
    homepage = "https://github.com/vyzo/gerbil";
    license = licenses.lgpl21Only;
    platforms = platforms.unix;
  };

  outputsToInstall = [ "out" ];
  dontStrip = true;
}
