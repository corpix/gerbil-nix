{ gccStdenv, lib, pkgs, fetchurl
, git, openssl, autoconf, gcc, coreutils, gnused, gnugrep
, src, version
, gambit-git-version
, gambit-stamp-ymd
, gambit-stamp-hms
, gambit-targets
, gambit-c-opt ? "-O1", gambit-c-opt-rts ? "-O2"
, gambit-default-runtime-options ? ["iL" "fL" "-L" "tL"]
, enableOpenssl
, enableShared
}: let
  inherit (builtins)
    toString
  ;
  inherit (lib)
    concatStringsSep
    optionalString
    optional
    optionals
    getLib
  ;

  bootstrap = gccStdenv.mkDerivation {
    pname = "gambit-bootstrap";
    version = "4.9.5";

    src = fetchurl {
      url = "https://gambitscheme.org/4.9.5/gambit-v4_9_5.tgz";
      sha256 = "sha256-4o74218OexFZcgwVAFPcq498TK4fDlyDiUR5cHP4wdw=";
    };

    buildInputs = [ autoconf ];

    configurePhase = ''
      export CC=${gcc}/bin/gcc \
             CXX=${gcc}/bin/g++ \
             CPP=${gcc}/bin/cpp \
             CXXCPP=${gcc}/bin/cpp \
             LD=${gcc}/bin/ld \
             XMKMF=${coreutils}/bin/false
      ./configure --prefix=$out/gambit
    '';

    buildPhase = ''
      mkdir -p $out/gambit
      cp -rp . $out/gambit/
      make -j$NIX_BUILD_CORES bootstrap
    '';

    installPhase = ''
      cp -fa ./gsc-boot $out/gambit/
    '';

    forceShare = [ "info" ];
  };
in gccStdenv.mkDerivation rec {
  pname = "gambit";
  inherit src version bootstrap;

  nativeBuildInputs = [git autoconf];
  buildInputs = [openssl];

  patches = [./patch/0000-gambit-output-prefix.patch];
  patchFlags = ["-p0"];

  configureFlags = [
    "--enable-targets=${concatStringsSep "," gambit-targets}"
    "--enable-single-host"
    "--enable-c-opt=${gambit-c-opt}"
    "--enable-c-opt-rts=${gambit-c-opt-rts}"
    "--enable-gcc-opts"
    "--enable-trust-c-tco"
    "--enable-absolute-shared-libs"
    "--enable-default-runtime-options=${concatStringsSep "," gambit-default-runtime-options}"
    # fixme: https://git.tatikoma.dev/corpix/gerbil-nix/issues/4#issuecomment-473
    # "--enable-multiple-vms"
    # "--enable-multiple-threaded-vms"
    # # fixme: segfaults in case profile and/or coverage enabled
    # "--enable-profile"
    # "--enable-coverage"
    # # fixme: clean up this mess
    # "--enable-default-compile-options='(compactness 9)'" # Make life easier on the JS backend
    # "--enable-rtlib-debug" # used by Geiser, but only on recent-enough gambit, and messes js runtime
    # "--enable-debug" # Nope: enables plenty of good stuff, but also the costly console.log
    # "--enable-multiple-versions" # Nope, NixOS already does version multiplexing
    # "--enable-guide"
    # "--enable-track-scheme"
    # "--enable-high-res-timing"
    # "--enable-max-processors=4"
    # "--enable-dynamic-tls"
    # "--enable-thread-system=posix"    # default when --enable-multiple-vms is on.
    # "--enable-char-size=1" # default is 4
    # "--enable-march=native" # Nope, makes it not work on machines older than the builder
    # "--enable-inline-jumps"
  ]
  ++ optionals (enableOpenssl) [
    "--enable-openssl"
  ]
  ++ optionals (enableShared) [
    "--enable-shared"
    "--enable-dynamic-clib"
  ]
  # Do not enable poll on darwin due to https://github.com/gambit/gambit/issues/498
  ++ optional (!gccStdenv.isDarwin) "--enable-poll";

  configurePhase = let
    opensslPathFix = ''
      substituteInPlace config.status \
        ${optionalString (gccStdenv.isDarwin) ''--replace-fail "/usr/local/opt/openssl@1.1" "${getLib openssl}"''} \
        --replace-fail "/usr/local/opt/openssl" "${getLib openssl}"
    '';
  in ''
    env

    substituteInPlace configure \
      --replace-fail "$(grep '^PACKAGE_VERSION=.*$' configure)" 'PACKAGE_VERSION="v${gambit-git-version}"' \
      --replace-fail "$(grep '^PACKAGE_STRING=.*$' configure)" 'PACKAGE_STRING="Gambit v${gambit-git-version}"' ;
    substituteInPlace include/makefile.in \
      --replace-fail '$(GIT) describe --tag --always' 'echo "v${gambit-git-version}"' \
      --replace-fail 'echo > stamp.h;' "(${
        concatStringsSep " " [
          ''echo '#define ___STAMP_VERSION \"v${gambit-git-version}\"';''
          ''echo '#define ___STAMP_YMD ${toString gambit-stamp-ymd}';''
          ''echo '#define ___STAMP_HMS ${toString gambit-stamp-hms}';''
        ]
      }) > stamp.h;";

    ./configure --prefix=$out/gambit ${concatStringsSep " " configureFlags}

    ${optionalString enableOpenssl opensslPathFix}

    ./config.status
  '';

  buildPhase = ''
    echo "Make bootstrap compiler, from release bootstrap"
    mkdir -p boot
    cp -rp ${bootstrap}/gambit/. boot/.
    chmod -R u+w boot
    cd boot
    cp ../gsc/makefile.in ../gsc/*.scm gsc/
    echo > include/stamp.h # No stamp needed for the bootstrap compiler
    ./configure
    for dir in lib gsi gsc
    do
      cd $dir
      make -j$NIX_BUILD_CORES
      cd -
    done
    cd ..
    cp boot/gsc/gsc gsc-boot

    echo "Use bootstrap compiler to build Gambit"
    set -x
    make -j$NIX_BUILD_CORES from-scratch
    make -j$NIX_BUILD_CORES modules
    set +x
  '';

  postInstall = ''
    mkdir -p $out/bin
    cd $out/bin
    ln -s $out/gambit/bin/* .
    cd -
    mkdir -p $out/lib
    mv $out/gambit/lib/libgambit* $out/lib
    cd $out/gambit/lib
    ln -s $out/lib/libgambit* .
    cd -
    mv $out/gambit/include $out/include
    ln -s $out/include $out/gambit/include
  '';

  doCheck = true;
  dontStrip = true;

  meta = with lib; {
    description = "Optimizing Scheme to C compiler";
    homepage = "http://gambitscheme.org";
    license = licenses.lgpl21Only;
    platforms = platforms.unix;
  };
}
