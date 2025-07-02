#!/bin/sh

main() {
  if [ ! -f ./hyprland-screenshoter.sh ]; then
    echo "hyprland-screenshoter.sh not found in the current directory."
    exit 1
  fi

  sudo ln -sf "${PWD}/hyprland-screenshoter.sh" /usr/local/bin/hyprland-screenshoter || return "$?"
}

main "$@" || exit "$?"
