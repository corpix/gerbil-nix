#! /usr/bin/env bash
set -e
set -x

# gets optional git tag/commit as first argument (otherwise use current master)
# prints out nix derivation code (not writing anything to existing files except local "cache" at .update-sh-gerbil/)

version=$1

if [ -d .update-sh-gerbil ]
then
    cd .update-sh-gerbil
    git pull -r origin master 1>&2
else
    git clone https://github.com/mighty-gerbils/gerbil .update-sh-gerbil 1>&2
    cd .update-sh-gerbil
fi

##

if [ ! -z "$version" ]
then
    git checkout "$version"
    rev="$version"
else
    rev=$(git rev-parse HEAD)
fi

version=${version:-unstable-$(date -u +"%Y-%m-%d")}
git_version=$(git describe --abbrev=0 --tags | sed 's/^v//g')
sha256sri=$(nix-prefetch-git --type sha256 --fetch-submodules --url https://github.com/mighty-gerbils/gerbil --rev $rev | jq -r .hash)

git submodule update --init --recursive
cd src/gambit

gambit_tag=$(git describe --abbrev=0 --tags)
gambit_version=$(echo $gambit_tag | sed 's/^v//g')
gambit_git_version="$gambit_version-$(git rev-list --count $gambit_tag..HEAD)-g$(git rev-parse --short HEAD)"
gambit_stamp_ymd=$(git --no-pager log -1 --format="%ad" --date=format:"%Y%m%d" | sed 's/^\s*//g')
gambit_stamp_hms=$(git --no-pager log -1 --format="%ad" --date=format:"%k%M%S" | sed 's/^\s*//g')

##

echo >&2

cat <<EOF
{ pkgs, stdenv, gccStdenv, callPackage, fetchFromGitHub
, gambit-unstable, gambit-support
, enableShared ? true
}:
callPackage ./build.nix rec {
  version = "gerbil-$version";
  git-version = "$git_version";
  src = fetchFromGitHub {
    owner = "mighty-gerbils";
    repo = "gerbil";
    rev = "$rev";
    hash = "$sha256sri";
    fetchSubmodules = true;
  };
  inherit enableShared gambit-support;
  gambit-params = gambit-support.unstable-params;
  gambit-git-version = "$gambit_git_version";
  gambit-stampYmd = "$gambit_stamp_ymd";
  gambit-stampHms = "$gambit_stamp_hms";
}
EOF
