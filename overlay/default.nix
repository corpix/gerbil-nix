_: prev: {
  gambit-git = prev.callPackage ../gambit.nix { };
  gerbil-git = prev.callPackage ../gerbil.nix { };
}
