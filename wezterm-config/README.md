# Wezterm Configuration

This repository contains my personal Wezterm configuration.

## File Location

On Linux, the configuration file should be placed at:
- `~/.wezterm.lua`

## Key Features

- **Color Scheme**: Tokyo Night (`tokyonight_night`)
- **Appearance**: 
  - Window opacity set to 0.95.
  - Font size: 14.
  - Integrated title bar buttons.
- **Custom Bindings**:
  - **Right Click**: Smart paste (pastes if no selection, copies and clears if there is a selection).
  - **Alt + D**: Split pane horizontally.
  - **Alt + Shift + D**: Split pane vertically.
  - **Alt + K**: Send `clear` command to the terminal.

## Installation

1. Copy `.wezterm.lua` to your home directory:
   ```bash
   cp .wezterm.lua ~/.wezterm.lua
   ```
2. Restart Wezterm or reload the configuration.
