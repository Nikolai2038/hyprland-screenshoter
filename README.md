# hyprland-screenshoter

## 1. Description

This script acts as a screenshoter for Hyprland.

## 2. Requirements

- Arch Linux:

    ```sh
    sudo pacman --noconfirm --sync --refresh --needed hyprshot hyprpicker swappy pngquant wl-clipboard
    ```

## 3. Installation

```sh
./install.sh
```

## 4. Usage

### 4.1. CLI

```sh
hyprland-screenshoter <region|window|output> <is_edit> <is_save> <is_compress>
```

Example:

```sh
hyprland-screenshoter region 1 0 0
```

### 4.2. Hyprland keybindings

Example:

```conf
# ========================================
# Hyprland Screenshoter
# (see https://github.com/Nikolai2038/hyprland-screenshoter)
# ========================================
# Screenshot a region: PRINT
bind = , PRINT, exec, hyprland-screenshoter region 0

# Screenshot a region and edit it: SHIFT + PRINT
bind = SHIFT, PRINT, exec, hyprland-screenshoter region 1

# Screenshot a window: MOD + PRINT
bind = $mainMod, PRINT, exec, hyprland-screenshoter window 0

# Screenshot a window and edit it: MOD + SHIFT + PRINT
bind = $mainMod SHIFT, PRINT, exec, hyprland-screenshoter window 1

# Screenshot a monitor: MOD + CTRL + PRINT
bind = $mainMod CTRL, PRINT, exec, hyprland-screenshoter output 0

# Screenshot a monitor and edit it: MOD + CTRL + SHIFT + PRINT
bind = $mainMod CTRL SHIFT, PRINT, exec, hyprland-screenshoter output 1
# ========================================
```

## 5. Contribution

Feel free to contribute via [pull requests](https://github.com/Nikolai2038/hyprland-screenshoter/pulls) or [issues](https://github.com/Nikolai2038/hyprland-screenshoter/issues)!
