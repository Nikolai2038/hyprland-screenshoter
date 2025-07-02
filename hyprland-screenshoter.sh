#!/bin/sh

main() {
  if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <mode> [is_edit]" >&2
    echo "Where:" >&2
    echo "- \"mode\" is one of:" >&2
    echo "  - \"region\": Select region;" >&2
    echo "  - \"window\": Select window;" >&2
    echo "  - \"output\": Select screen;" >&2
    echo "- \"is_edit\" is one of:" >&2
    echo "  - \"0\": Do not edit the screenshot;" >&2
    echo "  - \"1\": Edit the screenshot via \"swappy\"." >&2
    return 1
  fi

  __mode="$1" && shift
  __is_edit="${1:-0}" && shift

  # Screenshoter:
  # - "hyprshot": Takes screenshot;
  # - "swappy": Draw shapes on screenshot. Close window to finish work;
  # - "pngquant": Compress result image. This gives output with 2-3 times less space, and the quality is almost perfectly the same;
  # - "tee": Save image to the file;
  # - "wl-copy": Copy image to clipboard.
  if [ "${__is_edit}" -eq 1 ]; then
    hyprshot --freeze --silent --mode="${__mode}" --raw \
      | swappy --file - --output-file - \
      | pngquant --skip-if-larger --speed 1 --strip - \
      | tee "${HOME}/Pictures/Screenshots/$(date +'%Y/%m/%Y-%m-%d_%H-%M-%S').png" \
      | wl-copy || return "$?"
  else
    hyprshot --freeze --silent --mode="${__mode}" --raw \
      | pngquant --skip-if-larger --speed 1 --strip - \
      | tee "${HOME}/Pictures/Screenshots/$(date +'%Y/%m/%Y-%m-%d_%H-%M-%S').png" \
      | wl-copy || return "$?"
  fi
}

main "$@" || exit "$?"
