{ pkgs, stdenv, callPackage, fetchFromGitHub
, gambit-git, zlib, openssl, sqlite
, enableShared ? true
}:
callPackage ./gerbil-builder.nix rec {
  version = "0.18.1";
  src = fetchFromGitHub {
    owner = "mighty-gerbils";
    repo = "gerbil";
    rev = "ba78b313e82c064fc1c153a93df2673e41c6d4f3";
    hash = "sha256-ohoS4kOsMa/lVe+9iy0M+0mQfEA3t6nzFCL8IeXo3Yk=";
    fetchSubmodules = true;
  };
  gerbil-git-version = "0.18.1-125-gba78b313";

  inherit gambit-git zlib openssl sqlite enableShared;
}
