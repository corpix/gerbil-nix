{ pkgs, stdenv, callPackage, fetchFromGitHub
, gambit-unstable, gambit-support
, enableShared ? true
}:
callPackage ./gerbil-builder.nix rec {
  version = "0.18.1";
  src = fetchFromGitHub {
    owner = "mighty-gerbils";
    repo = "gerbil";
    rev = "708c85bda352e9aa2413e8690f61b8a51cc6ade1";
    hash = "sha256-e1Lkudu8XTLyZl//othmY5D18nJxILaIJNaVOwv5MVc=";
    fetchSubmodules = true;
  };
  gerbil-git-version = "0.18.1-111-g708c85bd";
  gambit-git-version = "4.9.5-130-g09335d95";
  gambit-stamp-ymd = "20240407";
  gambit-stamp-hms = "75009";

  inherit enableShared;
}
