#! /usr/bin/env bash
set -e
set -x

root=$(pwd)
dir=gerbil

gerbil_fetch_helper=fetchFromGitHub
gerbil_fetch_owner=mighty-gerbils
gerbil_fetch_repo=gerbil
gerbil_repo=https://github.com/$gerbil_fetch_owner/$gerbil_fetch_repo

gambit_fetch_helper=fetchFromGitHub
gambit_fetch_owner=gambit
gambit_fetch_repo=gambit
gambit_repo=https://github.com/$gambit_fetch_owner/$gambit_fetch_repo

# gets optional git tag/commit as first argument
# (otherwise use latest available from remote)
# writing gerbil.nix & gambit.nix
# to disable fetching run: NO_FETCH=y ./update.sh

version=$1
if [ -z "$NO_FETCH" ]
   then
       if [ -d $dir ]
       then
           cd $dir
           git pull -r origin master 1>&2
       else
           git clone $gerbil_repo $dir 1>&2
           cd $dir
       fi
else
    cd $dir
fi

##

if [ ! -z "$version" ]
then
    git checkout "$version"
    gerbil_rev="$version"
else
    gerbil_rev=$(git rev-parse HEAD)
fi

gerbil_tag=$(git describe --abbrev=0 --tags)
gerbil_version=$(echo $gerbil_tag | sed 's/^v//g')
gerbil_git_version="$gerbil_version-$(git rev-list --count $gerbil_tag..HEAD)-g$(git rev-parse --short HEAD)"
gerbil_sha256sri=$(nix-prefetch-git --type sha256 --fetch-submodules --url $gerbil_repo --rev $gerbil_rev | jq -r .hash)

git submodule update --init --recursive
cd src/gambit
gambit_rev=$(git rev-parse HEAD)
gambit_tag=$(git describe --abbrev=0 --tags)
gambit_version=$(echo $gambit_tag | sed 's/^v//g')
gambit_git_version="$gambit_version-$(git rev-list --count $gambit_tag..HEAD)-g$(git rev-parse --short HEAD)"
gambit_sha256sri=$(nix-prefetch-git --type sha256 --fetch-submodules --url $gambit_repo --rev $gambit_rev | jq -r .hash)
gambit_stamp_ymd=$(git --no-pager log -1 --format="%ad" --date=format:"%Y%m%d" | sed 's/^\s*//g')
gambit_stamp_hms=$(git --no-pager log -1 --format="%ad" --date=format:"%k%M%S" | sed 's/^\s*//g')

##

echo >&2

cd $root

cat <<EOF > gambit.nix
{ pkgs, stdenv, callPackage, $gambit_fetch_helper
, enableShared ? true
}:
callPackage ./gambit-builder.nix rec {
  version = "$gambit_version";
  src = $gambit_fetch_helper {
    owner = "$gambit_fetch_owner";
    repo = "$gambit_fetch_repo";
    rev = "$gambit_rev";
    hash = "$gambit_sha256sri";
  };
  gambit-targets = ["js"];
  gambit-git-version = "$gambit_git_version";
  gambit-stamp-ymd = "$gambit_stamp_ymd";
  gambit-stamp-hms = "$gambit_stamp_hms";

  inherit enableShared;
}
EOF

cat <<EOF > gerbil.nix
{ pkgs, stdenv, callPackage, $gerbil_fetch_helper
, gambit-git
, enableShared ? true
}:
callPackage ./gerbil-builder.nix rec {
  version = "$gerbil_version";
  src = $gerbil_fetch_helper {
    owner = "$gerbil_fetch_owner";
    repo = "$gerbil_fetch_repo";
    rev = "$gerbil_rev";
    hash = "$gerbil_sha256sri";
    fetchSubmodules = true;
  };
  gerbil-git-version = "$gerbil_git_version";

  inherit gambit-git enableShared;
}
EOF
