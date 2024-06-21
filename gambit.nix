{ pkgs, stdenv, callPackage, fetchFromGitHub
, enableShared ? true
}:
callPackage ./gambit-builder.nix rec {
  version = "4.9.5";
  src = fetchFromGitHub {
    owner = "gambit";
    repo = "gambit";
    rev = "09335d95cab6931791c0a8497cbe915053ff8af3";
    hash = "sha256-6mzhc6HyHI7RUB/Z8M4+zXSJmvUwPzAXEtwKBA3Sr+A=";
  };
  gambit-targets = ["js"];
  gambit-git-version = "4.9.5-130-g09335d95";
  gambit-stamp-ymd = "20240407";
  gambit-stamp-hms = "75009";

  inherit enableShared;
}
