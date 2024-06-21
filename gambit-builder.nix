{ gccStdenv, lib, pkgs, fetchurl
, git, openssl, autoconf, gcc, coreutils, gnused, gnugrep
, src, version
, gambit-git-version
, gambit-stamp-ymd
, gambit-stamp-hms
, gambit-targets
, gambit-c-opt ? "-O1", gambit-c-opt-rts ? "-O2"
, gambit-default-runtime-options ? ["iL" "fL" "-L" "tL"]
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
      export CC=${gcc}/bin/gcc CXX=${gcc}/bin/g++ \
             CPP=${gcc}/bin/cpp CXXCPP=${gcc}/bin/cpp LD=${gcc}/bin/ld \
             XMKMF=${coreutils}/bin/false
      unset CFLAGS LDFLAGS LIBS CPPFLAGS CXXFLAGS
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

  nativeBuildInputs = [ git autoconf ];
  buildInputs = [ openssl ];

  configureFlags = [
    "--enable-targets=${concatStringsSep "," gambit-targets}"
    "--enable-single-host"
    "--enable-c-opt=${gambit-c-opt}"
    "--enable-c-opt-rts=${gambit-c-opt-rts}"
    "--enable-gcc-opts"
    "--enable-trust-c-tco"
    "--enable-openssl"
    "--enable-absolute-shared-libs"
    "--enable-default-runtime-options=${concatStringsSep "," gambit-default-runtime-options}"
    # fixme: https://git.tatikoma.dev/corpix/gerbil-nix/issues/4#issuecomment-473
    # "--enable-multiple-vms"
    # "--enable-multiple-threaded-vms"
    # "--enable-profile"
    # "--enable-coverage"
    # fixme: clean up this mess
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
  ++ optionals (enableShared) [
    "--enable-shared"
    "--enable-dynamic-clib"
  ]
  # Do not enable poll on darwin due to https://github.com/gambit/gambit/issues/498
  ++ optional (!gccStdenv.isDarwin) "--enable-poll";

  configurePhase = ''
    export CC=${gccStdenv.cc}/bin/${gccStdenv.cc.targetPrefix}gcc \
           CXX=${gccStdenv.cc}/bin/${gccStdenv.cc.targetPrefix}g++ \
           CPP=${gccStdenv.cc}/bin/${gccStdenv.cc.targetPrefix}cpp \
           CXXCPP=${gccStdenv.cc}/bin/${gccStdenv.cc.targetPrefix}cpp \
           LD=${gccStdenv.cc}/bin/${gccStdenv.cc.targetPrefix}ld \
           XMKMF=${coreutils}/bin/false
    unset CFLAGS LDFLAGS LIBS CPPFLAGS CXXFLAGS

    echo "Fixing timestamp recipe in Makefile"
    substituteInPlace configure \
      --replace "$(grep '^PACKAGE_VERSION=.*$' configure)" 'PACKAGE_VERSION="v${gambit-git-version}"' \
      --replace "$(grep '^PACKAGE_STRING=.*$' configure)" 'PACKAGE_STRING="Gambit v${gambit-git-version}"' ;
    substituteInPlace include/makefile.in \
      --replace "\$\$(\$(GIT) describe --tag --always | sed 's/-bootstrap\$\$//')" "v${gambit-git-version}" \
      --replace "echo > stamp.h;" "(${
        concatStringsSep " " [
          ''echo '#define ___STAMP_VERSION \"v${gambit-git-version}\"';''
          ''echo '#define ___STAMP_YMD ${toString gambit-stamp-ymd}';''
          ''echo '#define ___STAMP_HMS ${toString gambit-stamp-hms}';''
        ]
      }) > stamp.h;";

    ./configure --prefix=$out/gambit ${concatStringsSep " " configureFlags}

    substituteInPlace config.status \
      ${optionalString (gccStdenv.isDarwin) ''--replace "/usr/local/opt/openssl@1.1" "${getLib openssl}"''} \
      --replace "/usr/local/opt/openssl" "${getLib openssl}"

    ./config.status
  '';

  buildPhase = ''
    # The MAKEFLAGS setting is a workaround for https://github.com/gambit/gambit/issues/833
    export MAKEFLAGS="--output-sync=recurse"
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
    make -j$NIX_BUILD_CORES from-scratch
    make -j$NIX_BUILD_CORES modules
  '';

  postInstall = ''
    mkdir $out/bin
    cd $out/bin
    ln -s ../gambit/bin/* .
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
