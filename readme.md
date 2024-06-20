# gerbil-nix

A package overlay which builds Gerbil Scheme.

## updating version

```console
$ make update
```

results will be written into `gerbil.nix`

## building gerbil packages

You may use this snippet as part of `flake.nix`:

> don't forget to add this flake into your inputs to have access to `gerbil.stdenv`

```
gerbil.stdenv.x86_64-linux.static.mkGerbilPackage {
  name = "mk-gerbil-package-test";
  version = "unstable";
  src = ./test/mk-gerbil-package/.;
  buildPhase = ''
    gxc hello.ss
  '';
  installPhase = ''
    mkdir -p $out/gerbil
    mv .gerbil/lib $out/gerbil
  '';
};
```
