#!/bin/sh

main() {
  if [ ! -f ./hyprland-screenshoter.sh ]; then
    echo "hyprland-screenshoter.sh not found in the current directory."
    return 1
  fi

  # NOTE: Previously I used symlink, but don't want to be dependent on it anymore
  if [ -e /usr/local/bin/hyprland-screenshoter ]; then
    sudo rm /usr/local/bin/hyprland-screenshoter || return "$?"
  fi

  sudo cp -T "${PWD}/hyprland-screenshoter.sh" /usr/local/bin/hyprland-screenshoter || return "$?"
}

main "$@" || exit "$?"
