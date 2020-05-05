#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
if ! command -v strap::lib::import >/dev/null; then
  echo "This file is not intended to be run or sourced outside of a strap execution context." >&2
  [[ "${BASH_SOURCE[0]}" != "${0}" ]] && return 1 || exit 1 # if sourced, return 1, else running as a command, so exit
fi

strap::lib::import lang || . lang.sh
strap::lib::import logging || . logging.sh
strap::lib::import path || . path.sh
strap::lib::import os || . os.sh

set -a

strap::pkgmgr::id() {
  local id

  if [[ "$STRAP_OS" == 'mac' ]] || command -v brew >/dev/null 2>&1; then
    id='brew'
  elif command -v yum >/dev/null 2>&1; then
    id='yum'
  elif command -v apt-get >/dev/null 2>&1; then
    id='aptget'
  else
    echo "Unable to detect $STRAP_OS package manager" >&2
    return 1
  fi

  echo "$id"
}

export STRAP_PKGMGR_ID="$(strap::pkgmgr::id)"

strap::pkgmgr::init() {
  strap::lib::import "$STRAP_PKGMGR_ID" # id is also a package name in lib (i.e. lib/<name>.sh
  "strap::${STRAP_PKGMGR_ID}::init" # init the pkg mgr
}

strap::pkgmgr::pkg::is_installed() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be the package id'
  "strap::${STRAP_PKGMGR_ID}::pkg::is_installed" "$id"
}

strap::pkgmgr::pkg::install() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be the package id'
  "strap::${STRAP_PKGMGR_ID}::pkg::install" "$id"
}

strap::pkgmgr::pkg::ensure() {
  local id="${1:-}" && strap::assert::has_length "$id" '$1 must be the package id'
  strap::running "Checking $id"
  if ! strap::pkgmgr::pkg::is_installed "$id"; then
    strap::action "Installing $id"
    strap::pkgmgr::pkg::install "$id"
  fi
  strap::ok
}

set +a