#!/bin/bash

FILE_EXTENSION=".png"

# Apply fixes to hide cursor
#
# Usage: hide_cursor
hide_cursor() {
  echo "Applying fixes to hide cursor..." >&2

  # We must set this variables so the Cursor, which selects the region, is not drawn in the screenshot.
  # NOTE: This is not applicable for the cursor hovered over some text (in terminal, IDE, etc.).
  # See https://github.com/Gustash/Hyprshot/issues/64
  # See https://github.com/hyprwm/Hyprland/issues/1520
  hyprctl keyword cursor:no_hardware_cursors false || return "$?"
  hyprctl keyword cursor:use_cpu_buffer true || return "$?"

  echo "Applying fixes to hide cursor: success!" >&2
}

# Take screenshot
#
# Usage: screenshot_take <file_path> <mode>
screenshot_take() {
  __file_path="$1" && shift
  __mode="$1" && shift

  echo "Taking screenshot..." >&2

  __file_dir="$(dirname "${__file_path}")" || return "$?"
  __file_name="$(basename "${__file_path}")" || return "$?"

  # Take screenshot and save to temporary file.
  # NOTE: We write directly to the file and not via stdout pipe, because sometimes in bugs out and no image is copied in the end.
  hyprshot --freeze --silent --mode="${__mode}" --output-folder "${__file_dir}" --filename "${__file_name}" || return "$?"

  # Issue https://github.com/Nikolai2038/hyprland-screenshoter/issues/1
  local max_time_to_wait=5
  local waited_time=0
  while ! file "${__file_path}" | grep --quiet 'PNG image data'; do
    echo "Image \"${__file_path}\" is not a valid PNG image yet. Waiting 1 second..." >&2
    sleep 1

    waited_time="$((waited_time + 1))"
    if [ "${waited_time}" -ge "${max_time_to_wait}" ]; then
      echo "Timed out waiting for image \"${__file_path}\" to become a valid PNG image." >&2
      return 1
    fi
  done

  echo "Taking screenshot: success!" >&2
}

# Edit screenshot
#
# Usage: image_edit <file_path>
image_edit() {
  __file_path="$1" && shift

  echo "Editing image \"${__file_path}\"..." >&2

  # Use "swappy" to draw shapes on the image.
  # NOTE: Close window to finish work.
  swappy --file "${__file_path}" --output-file "${__file_path}" || return "$?"

  echo "Editing image \"${__file_path}\": success!" >&2
}

# Compress image
#
# Usage: image_compress <file_path>
image_compress() {
  __file_path="$1" && shift

  echo "Compressing image \"${__file_path}\"..." >&2

  # Compress result image. This gives output with 2-3 times less space, and the quality is almost perfectly the same
  pngquant --skip-if-larger --speed 1 --strip "${__file_path}" --ext "${FILE_EXTENSION}" --force || return "$?"

  echo "Compressing image \"${__file_path}\": success!" >&2
}

# Copy image to the clipboard
#
# Usage: image_copy <file_path>
image_copy() {
  __file_path="$1" && shift

  echo "Copying image \"${__file_path}\" to the clipboard..." >&2

  # Copy result image to clipboard
  cat "${__file_path}" | wl-copy || return "$?"

  echo "Copying image \"${__file_path}\" to the clipboard: success!" >&2
}

# Remove specified file
#
# Usage: remove_file <file_path>
remove_file() {
  __file_path="$1" && shift

  echo "Removing file..." >&2
  rm "${__file_path}" || return "$?"
  echo "Removing file: success!" >&2
}

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

  # Issue https://github.com/Nikolai2038/hyprland-screenshoter/issues/2
  __mode="$1" && shift
  __is_edit="${1:-0}" && shift
  __is_save="${1:-1}" && shift
  __is_compress="${1:-1}" && shift

  if [ "${__is_save}" = "0" ]; then
    # Create temp file
    __file_path="$(mktemp --suffix="${FILE_EXTENSION}")" || return "$?"

    # Add return handler - To clear temp file (only on first return after this)
    trap "remove_file; trap - RETURN" RETURN
  else
    __file_path="${HOME}/Pictures/Screenshots/$(date +'%Y/%m/%Y-%m-%d_%H-%M-%S')${FILE_EXTENSION}" || return "$?"
  fi

  hide_cursor || return "$?"
  screenshot_take "${__file_path}" "${__mode}" || return "$?"

  # Edit image, if needed
  if [ "${__is_edit}" = "1" ]; then
    image_edit "${__file_path}" || return "$?"
  fi

  # Compress image, if needed
  if [ "${__is_compress}" = "1" ]; then
    image_compress "${__file_path}" || return "$?"
  fi

  image_copy "${__file_path}" || return "$?"

  if [ "${__is_save}" = "0" ]; then
    # Clear return handler
    trap - RETURN

    # Clear temp file
    remove_file "${__file_path}" || return "$?"
  fi
}

main "$@" || exit "$?"
