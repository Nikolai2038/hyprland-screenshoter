#!/usr/bin/env bash

# Fail the pipeline when any of its commands fails
set -o pipefail || exit "$?"

# Extension of the screenshot files
_FILE_EXTENSION='.png'

# Applies the fixes to hide the cursor from the screenshots
#
# Return codes:
#
# - `0`: The fixes were applied;
# - Other: The error code of `hyprctl`.
hide_cursor() {
  echo 'Applying fixes to hide cursor...' >&2

  # We must set this variables so the Cursor, which selects the region, is not drawn in the screenshot.
  # NOTE: This is not applicable for the cursor hovered over some text (in terminal, IDE, and so on).
  #       See https://github.com/Gustash/Hyprshot/issues/64
  #       See https://github.com/hyprwm/Hyprland/issues/1520
  # NOTE: A Lua config (Hyprland 0.55 and newer) refuses "hyprctl keyword" and takes "hyprctl eval" instead.
  #       A ".conf" config, and Hyprland before 0.55, do not answer "ok" to "hyprctl eval", so "hyprctl keyword" is used for them.
  #       See https://wiki.hypr.land/configuring/core/advanced-configuration/using-hyprctl/#eval
  local eval_result=''
  eval_result="$(hyprctl eval 'hl.config({ cursor = { no_hardware_cursors = false, use_cpu_buffer = true } })')" || eval_result=''
  if [ "${eval_result}" != 'ok' ]; then
    hyprctl keyword cursor:no_hardware_cursors 'false' || return "$?"
    hyprctl keyword cursor:use_cpu_buffer 'true' || return "$?"
  fi

  echo 'Applying fixes to hide cursor: success!' >&2
}

# Answers whether the file holds a PNG image
#
# Usage: `is_png_file <path_to_file>`.
#
# Where:
#
# - `path_to_file`: Path to the file to check.
#
# Return codes:
#
# - `0`: The file holds a PNG image;
# - `1`: The file does not hold a PNG image (the answer, not a failure).
is_png_file() {
  local path_to_file="${1-}" && shift "$(($# > 0))"

  local file_description=''
  file_description="$(file -- "${path_to_file}")" || file_description=''

  if [ "${file_description#*"PNG image data"}" != "${file_description}" ]; then
    return 0
  fi

  return 1
}

# Takes a screenshot of the specified mode into the specified file
#
# Usage: `screenshot_take <path_to_file> <mode>`.
#
# Where:
#
# - `path_to_file`: Path to the file to save the screenshot into;
# - `mode`: Mode of the screenshot, one of `region`, `window` or `output`.
#
# Return codes:
#
# - `0`: The screenshot was taken;
# - `1`: The file did not become a valid PNG image within the wait time;
# - Other: The error code of `hyprshot`, `hyprpicker` or another tool used.
screenshot_take() {
  local path_to_file="${1-}" && shift "$(($# > 0))"
  local mode="${1-}" && shift "$(($# > 0))"

  echo 'Taking screenshot...' >&2

  local path_to_file_directory=''
  path_to_file_directory="$(dirname -- "${path_to_file}")" || return "$?"

  local file_name=''
  file_name="$(basename -- "${path_to_file}")" || return "$?"

  declare -a hyprpicker_args=(
    --quiet
    --no-zoom
    --no-fancy
    --render-inactive
  )

  local hyprpicker_help=''
  hyprpicker_help="$(hyprpicker --help)" || hyprpicker_help=''

  local grep_code=0
  echo "${hyprpicker_help}" | grep -- '--disable-preview' > /dev/null || grep_code="$?"
  if [ "${grep_code}" -gt 1 ]; then
    return "${grep_code}"
  fi

  if [ "${grep_code}" -eq 0 ]; then
    hyprpicker_args+=(--disable-preview)
  else
    grep_code=0
    echo "${hyprpicker_help}" | grep -- '--disable-hex-preview' > /dev/null || grep_code="$?"
    if [ "${grep_code}" -gt 1 ]; then
      return "${grep_code}"
    fi

    if [ "${grep_code}" -eq 0 ]; then
      # NOTE: Older versions of hyprpicker use "--disable-hex-preview" instead of "--disable-preview"
      hyprpicker_args+=(--disable-hex-preview)
    fi
  fi

  # Freeze screen in the background
  # NOTE: We don't use "hyprshot --freeze", because it does not properly copy freezed content.
  #       For example, some menu pop-ups, which looks like frozen, for some reason will not appear in the final screenshot.
  #       This happens for me with some pop-ups (not always, but frequently) on sites in the browser (Firefox).
  # NOTE: We add timeout for hyprpicker, because sometimes it may start after "hyprshot" even with "sleep".
  #       In this case, screen will be freezed and you can't do nothing, except switching to another TTY and killing via "pkill -SIGKILL hyprpicker".
  #       So we kill it after 30 seconds to be able to have some solution.
  #       It happened to me from time to time on decent performance machine with "sleep 0.05", so I increased it.
  timeout 30 hyprpicker "${hyprpicker_args[@]}" &

  local hyprpicker_pid="$!"
  sleep 0.2 || return "$?"

  # Take screenshot and save to temporary file.
  # NOTE: We write directly to the file and not via stdout pipe, because sometimes in bugs out and no image is copied in the end.
  hyprshot --silent --mode="${mode}" --output-folder "${path_to_file_directory}" --filename "${file_name}" || return "$?"

  # Unfreeze screen
  kill "${hyprpicker_pid}" || return "$?"

  # ISSUE: https://github.com/Nikolai2038/hyprland-screenshoter/issues/1.
  local max_time_to_wait=5
  local waited_time=0
  while ! is_png_file "${path_to_file}"; do
    echo "Image \"${path_to_file}\" is not a valid PNG image yet. Waiting 1 second..." >&2
    sleep 1 || return "$?"

    waited_time="$((waited_time + 1))" || return "$?"
    if [ "${waited_time}" -ge "${max_time_to_wait}" ]; then
      echo "Timed out waiting for image \"${path_to_file}\" to become a valid PNG image." >&2
      return 1
    fi
  done

  echo 'Taking screenshot: success!' >&2
}

# Opens the image in "swappy" to draw shapes on it, saving the result into the same file
#
# Usage: `image_edit <path_to_file>`.
#
# Where:
#
# - `path_to_file`: Path to the image file to edit.
#
# Return codes:
#
# - `0`: The image was edited;
# - Other: The error code of `swappy`.
image_edit() {
  local path_to_file="${1-}" && shift "$(($# > 0))"

  echo "Editing image \"${path_to_file}\"..." >&2

  # Use "swappy" to draw shapes on the image.
  # NOTE: Close window to finish work.
  swappy --file "${path_to_file}" --output-file "${path_to_file}" || return "$?"

  echo "Editing image \"${path_to_file}\": success!" >&2
}

# Compresses the image in place via "pngquant"
#
# Usage: `image_compress <path_to_file>`.
#
# Where:
#
# - `path_to_file`: Path to the image file to compress.
#
# Return codes:
#
# - `0`: The image was compressed;
# - Other: The error code of `pngquant`.
image_compress() {
  local path_to_file="${1-}" && shift "$(($# > 0))"

  echo "Compressing image \"${path_to_file}\"..." >&2

  # Compress result image. This gives output with 2-3 times less space, and the quality is almost perfectly the same.
  pngquant --skip-if-larger --speed 1 --strip "${path_to_file}" --ext "${_FILE_EXTENSION:?}" --force || return "$?"

  echo "Compressing image \"${path_to_file}\": success!" >&2
}

# Copies the image to the clipboard via "wl-copy"
#
# Usage: `image_copy <path_to_file>`.
#
# Where:
#
# - `path_to_file`: Path to the image file to copy.
#
# Return codes:
#
# - `0`: The image was copied;
# - Other: The error code of `wl-copy`.
image_copy() {
  local path_to_file="${1-}" && shift "$(($# > 0))"

  echo "Copying image \"${path_to_file}\" to the clipboard..." >&2

  # Copy result image to clipboard
  wl-copy < "${path_to_file}" || return "$?"

  echo "Copying image \"${path_to_file}\" to the clipboard: success!" >&2
}

# Removes the specified file
#
# Usage: `remove_file <path_to_file>`.
#
# Where:
#
# - `path_to_file`: Path to the file to remove.
#
# Return codes:
#
# - `0`: The file was removed;
# - Other: The error code of `rm`.
remove_file() {
  local path_to_file="${1-}" && shift "$(($# > 0))"

  echo 'Removing file...' >&2
  rm -- "${path_to_file}" || return "$?"
  echo 'Removing file: success!' >&2
}

# Takes a screenshot of the region, window or output, then edits, compresses, copies it to the clipboard and saves it as configured
#
# Usage: `hyprland_screenshoter <mode> [<is_edit>] [<is_save>] [<is_compress>]`.
#
# Where:
#
# - `mode`: What to screenshot: `region` to select a region, `window` to select a window, `output` to select a screen;
# - `is_edit`: `1` to edit the screenshot via "swappy", `0` not to. `0` by default;
# - `is_save`: `1` to save the screenshot to "~/Pictures/Screenshots/", `0` to use a temporary file. `1` by default;
# - `is_compress`: `1` to compress the image via "pngquant", `0` not to. `1` by default.
#
# Return codes:
#
# - `0`: The screenshot was taken and processed;
# - `1`: Invalid usage;
# - Other: The error code of one of the functions it calls.
hyprland_screenshoter() {
  if [ "$#" -lt 1 ]; then
    echo 'Usage: hyprland_screenshoter <mode> [<is_edit>] [<is_save>] [<is_compress>]
Where:
- "mode" is one of:
  - "region": Select region;
  - "window": Select window;
  - "output": Select screen;
- "is_edit" is one of:
  - "0": Do not edit the screenshot;
  - "1": Edit the screenshot via "swappy";
- "is_save" is one of:
  - "0": Use a temporary file, cleared on return;
  - "1": Save the screenshot to "~/Pictures/Screenshots/";
- "is_compress" is one of:
  - "0": Do not compress the screenshot;
  - "1": Compress the screenshot via "pngquant".' >&2
    return 1
  fi

  # ISSUE: https://github.com/Nikolai2038/hyprland-screenshoter/issues/2.
  local mode="${1-}" && shift "$(($# > 0))"
  local is_edit="${1:-0}" && shift "$(($# > 0))"
  local is_save="${1:-1}" && shift "$(($# > 0))"
  local is_compress="${1:-1}" && shift "$(($# > 0))"

  local path_to_file=''
  if [ "${is_save}" = '0' ]; then
    # Create a temporary file
    path_to_file="$(mktemp --suffix="${_FILE_EXTENSION:?}")" || return "$?"

    # Add a return handler to clear the temporary file (only on the first return after this)
    trap "remove_file; trap - RETURN" RETURN
  else
    path_to_file="${HOME}/Pictures/Screenshots/$(date +'%Y/%m/%Y-%m-%d_%H-%M-%S')${_FILE_EXTENSION:?}" || return "$?"
  fi

  hide_cursor || return "$?"
  screenshot_take "${path_to_file}" "${mode}" || return "$?"

  # Edit image, if needed
  if [ "${is_edit}" = '1' ]; then
    image_edit "${path_to_file}" || return "$?"
  fi

  # Compress image, if needed
  if [ "${is_compress}" = '1' ]; then
    image_compress "${path_to_file}" || return "$?"
  fi

  image_copy "${path_to_file}" || return "$?"

  if [ "${is_save}" = '0' ]; then
    # Clear return handler
    trap - RETURN

    # Clear the temporary file
    remove_file "${path_to_file}" || return "$?"
  fi
}

hyprland_screenshoter "$@" || exit "$?"
