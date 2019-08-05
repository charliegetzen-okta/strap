#!/usr/bin/env bash

set -Eeuo pipefail # https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/

command -v strap::lib::import >/dev/null || { echo "strap::lib::import is not available" >&2; exit 1; }
strap::lib::import logging || . logging.sh

STRAP_DEBUG="${STRAP_DEBUG:-}"
STRAP_HOME="${STRAP_HOME:-}" && [[ -z "$STRAP_HOME" ]] && echo "STRAP_HOME is not set." >&2 && exit 1
STRAP_USER_HOME="${STRAP_USER_HOME:-}" && [[ -z "$STRAP_USER_HOME" ]] && echo "STRAP_USER_HOME is not set." >&2 && exit 1
STRAP_SUDO_PROMPT="${STRAP_SUDO_PROMPT:-}" && [[ -z "$STRAP_SUDO_PROMPT" ]] && STRAP_SUDO_PROMPT=true # default
STRAP_SUDO_CLEANED=''

set -a

STRAP_SUDO_WAIT_PID="${STRAP_SUDO_WAIT_PID:-}"
__strap__sudo__edit="$STRAP_HOME/etc/sudoers/edit"
__strap__sudo__cleanup="$STRAP_HOME/etc/sudoers/cleanup"

strap::sudo::cleanup() {

  [[ -n "$STRAP_SUDO_CLEANED" ]] && return 0

  chmod 700 "$__strap__sudo__cleanup"

  if sudo -vn >/dev/null 2>&1; then # sudo is still available, so we can call cleanup:
    sudo "$__strap__sudo__cleanup"
  fi

  if [[ -n "$STRAP_SUDO_WAIT_PID" ]]; then
    if kill "$STRAP_SUDO_WAIT_PID" >/dev/null 2>&1; then
      wait "$STRAP_SUDO_WAIT_PID" >/dev/null 2>&1 || true
    fi
    export STRAP_SUDO_WAIT_PID=''
  fi

  trap - SIGINT SIGTERM EXIT

  export STRAP_SUDO_CLEANED="1"

  sudo -k
}

strap::sudo::enable() {

  #[[ -n "$STRAP_SUDO_WAIT_PID" ]] && return 0 # already running

  trap 'strap::sudo::cleanup' SIGINT SIGTERM EXIT

  if [[ ! -f "$__strap__sudo__edit" || ! -f "$__strap__sudo__cleanup" ]]; then
    strap::abort "Invalid STRAP_HOME installation"
  fi

  # Ensure correct file permissions in case they're ever changed by accident:
  chmod 700 "$__strap__sudo__edit" "$__strap__sudo__cleanup"

  if [[ "$STRAP_SUDO_PROMPT" == true ]]; then # only false in CI
    sudo -k # clear out any cached time to ensure we start fresh
    sudo -p "Enter your sudo password: " "$__strap__sudo__edit" "$__strap__sudo__cleanup"
    sudo -v -p "Enter your sudo password (confirm): " # Required if system-wide timeout is zero. Does nothing otherwise.

    # spawn keepalive loop in background.  This will automatically exit after strap exits or
    # we explicitly kill it with its PID, whichever comes first:

    # disable debug output - it collides with the foreground debug output
    [ -n "$STRAP_DEBUG" ] && set +x
    while true; do sudo -vn >/dev/null 2>&1; sleep 1; kill -0 "$$" >/dev/null 2>&1 || exit; done &
    # re-enable debug output if necessary:
    [ -n "$STRAP_DEBUG" ] && set -x

    export STRAP_SUDO_WAIT_PID="$!"
  fi
}

set +a
