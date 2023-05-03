#!/usr/bin/env bash

set -euo pipefail

GH_REPO="https://github.com/godotengine/godot"
REPO="https://downloads.tuxfamily.org/godotengine"
TOOL_NAME="godot"
TOOL_TEST="godot --version"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//;s/-stable$//'
}

list_all_versions() {
  list_sub_versions
}

list_stable_versions() {
  list_github_tags
}

list_repo_versions() {
  curl -s "$REPO/" |
    xmllint --html --xpath "//a/text()" - |
    grep -P "[0-9]"
}


list_sub_versions() {
  versions=`curl -s "$REPO/" |
    xmllint --html --xpath "//a/text()" - |
    grep -P "[0-9]" |
    tr '\n' ' '`

  for version in $versions
  do
    local sub_versions=`curl -s "$REPO/$version/" |
    xmllint --html --xpath "//a/text()" - |
    grep -P "(beta|rc|dev)" |
    tr '\n' ' '`

    for sub in $sub_versions
    do
      echo "${version}-${sub}"
    done
    echo "${version}-stable"
  done

}

download_release() {
  local version filename url release linux_string
  version=`echo "$1" | cut -d'-' -f1`
  filename="$2"
  release=`echo "$1" | cut -d'-' -f2`
  linux_string="$3"

  if [[ "$release" == "stable" ]]; then
    url="$REPO/${version}/Godot_v${version}-${release}_${linux_string}.zip"
  else
    url="$REPO/${version}/${release}/Godot_v${version}-${release}_${linux_string}.zip"
  fi
  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}


install_version() {
  local linux_string
  local install_type="$1"
  local version="$2"
  local install_path="$3"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  if [[ $version == 4* ]]; then
    linux_string="linux.x86_64"
  else
    linux_string="x11.64"
  fi

  local release_file="$install_path/$TOOL_NAME-$version.zip"
  (
    mkdir -p "$install_path/bin"
    download_release "$version" "$release_file" "$linux_string"
    unzip -qq "$release_file" -d "$install_path" || fail "Could not extract $release_file"
    mv "$install_path/Godot_v${version}_${linux_string}" "$install_path/bin/godot"
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
