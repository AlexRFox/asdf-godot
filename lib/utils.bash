#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/godotengine/godot-builds"
GH_BUILDS_REPO="https://github.com/godotengine/godot-builds/releases/download"
REPO="https://downloads.tuxfamily.org/godotengine"
TOOL_NAME="godot"
TOOL_TEST="godot --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

sort_versions() {
  sort --version-sort --field-separator=.
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//'
}

list_all_versions() {
  list_github_tags
}

list_stable_versions() {
  list_github_tags | grep "stable"
}

latest_stable() {
  list_stable_versions | sort_versions | tail -n 1
}

get_sub_versions() {
  local sub_versions=`curl -s "$REPO/$1/" |
    grep Directory |
    grep -oP '(alpha|beta|rc|dev)([0-9]){0,2}' |
    uniq |
    tr '\n' ' '`

  for sub in $sub_versions
  do
    echo "${1}-${sub}"
  done
}

list_sub_versions() {
  versions=`curl -s "$REPO/" |
  grep Directory |
  grep -oP '([0-9](\.[0-9])+)' |
  uniq |
  tr '\n' ' '`

  for version in $versions
  do
    get_sub_versions $version &
  done
  wait
}


download_release() {
  local version filename url release platform
  version=`echo "$1" | cut -d'-' -f1`
  filename="$2"
  release=`echo "$1" | cut -d'-' -f2`
  platform="$3"
  url="$GH_BUILDS_REPO/$1/Godot_v$1_${platform}.zip"
  echo "asdjfkaljsdfklajsdkfjaskldf"

  echo "* Downloading $TOOL_NAME release $1..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}


install_version() {
  local linux_string
  local platform
  local install_type="$1"
  local version="$2"
  local install_path="$3"
  local regex='(alpha|beta|dev|rc)'

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  if [[ $version == 4* ]]; then
    linux_string="linux.x86_64"
  else
    linux_string="x11.64"
  fi

  if [[ ! $version =~ $regex ]]; then
    version="$version"
  fi

  case $(uname -s) in
    Darwin)
      platform="macos.universal"
      ;;
    *)
      platform="$(uname -s | awk '{print tolower($0)}').$(uname -m)"
      ;;
  esac

  local release_file="$install_path/$TOOL_NAME-$version.zip"
  (
    mkdir -p "$install_path/bin"
    download_release "$version" "$release_file" "$platform"
    fail "$release_file"
    unzip -qq "$release_file" -d "$install_path" || fail "Could not extract $release_file"
    mv "$install_path/Godot_v${version}_${platform}" "$install_path/bin/godot"
    rm "$release_file"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/bin/$tool_cmd" || fail "Expected $install_path/bin/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
