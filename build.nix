{ pkgs, lib, gccStdenv, coreutils
, openssl, zlib, sqlite
, version, git-version, src, enableShared
, gambit-support, gambit-git-version, gambit-stampYmd, gambit-stampHms, gambit-params
}:

# We use Gambit, that works 10x better with GCC than Clang. See ../gambit/build.nix
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

  buildInputs_libraries = [ openssl zlib sqlite ];

  # TODO: either fix all of Gerbil's dependencies to provide static libraries,
  # or give up and delete all tentative support for static libraries.
  #buildInputs_staticLibraries = map makeStaticLibraries buildInputs_libraries;

  buildInputs = buildInputs_libraries;

  postPatch = ''
    patchShebangs .
    grep -Fl '#!/usr/bin/env' `find . -type f -executable` | while read f
    do
      substituteInPlace "$f" --replace '#!/usr/bin/env' '#!${coreutils}/bin/env'
    done
    cat > MANIFEST <<EOF
    gerbil_stamp_version=v${git-version}
    gambit_stamp_version=v${gambit-git-version}
    gambit_stamp_ymd=${gambit-stampYmd}
    gambit_stamp_hms=${gambit-stampHms}
    EOF

    export GERBIL_GCC=${gccStdenv.cc}/bin/${gccStdenv.cc.targetPrefix}gcc
  '';

## TODO: make static compilation work.
## For that, get all the packages below to somehow expose static libraries,
## so we can offer users the option to statically link them into Gambit and/or Gerbil.
## Then add the following to the postPatch script above:
#     cat > etc/gerbil_static_libraries.sh <<EOF
# OPENSSL_LIBCRYPTO=${makeStaticLibraries openssl}/lib/libcrypto.a # MISSING!
# OPENSSL_LIBSSL=${makeStaticLibraries openssl}/lib/libssl.a # MISSING!
# ZLIB=${makeStaticLibraries zlib}/lib/libz.a
# SQLITE=${makeStaticLibraries sqlite}/lib/sqlite.a # MISSING!
# EOF

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
    ${gambit-support.export-gambopt gambit-params}

    # Build, replacing make by build.sh
    ( cd src && sh build.sh )

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
    homepage    = "https://github.com/vyzo/gerbil";
    license     = licenses.lgpl21Only;
    platforms   = platforms.unix;
  };

  outputsToInstall = [ "out" ];
  dontStrip = true;
}
