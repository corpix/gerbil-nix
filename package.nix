{ pkgs, stdenv, gccStdenv, callPackage, fetchFromGitHub
, gambit-unstable, gambit-support
, enableShared ? true
}:
callPackage ./build.nix rec {
  version = "gerbil-unstable-2024-05-11";
  git-version = "0.18.1";
  src = fetchFromGitHub {
    owner = "mighty-gerbils";
    repo = "gerbil";
    rev = "708c85bda352e9aa2413e8690f61b8a51cc6ade1";
    hash = "sha256-e1Lkudu8XTLyZl//othmY5D18nJxILaIJNaVOwv5MVc=";
    fetchSubmodules = true;
  };
  inherit enableShared gambit-support;
  gambit-params = gambit-support.unstable-params;
  gambit-git-version = "4.9.5-130-g09335d95";
  gambit-stampYmd = "20240407";
  gambit-stampHms = "75009";
}
