local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- General configuration
config.font_size = 14
config.line_height = 1.2
-- config.font = wezterm.font("BlexMono Nerd Font Mono")
-- config.color_scheme = "Catppuccin Mocha"
config.color_scheme = "tokyonight_night"
config.window_background_opacity = 0.95
config.window_close_confirmation = "NeverPrompt"
config.colors = {
	cursor_bg = "#7aa2f7",
	cursor_border = "#7aa2f7",
	cursor_fg = "#f5c2e7",
}

config.enable_tab_bar = true
config.initial_rows = 20
config.initial_cols = 170

config.window_decorations = "RESIZE"
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
config.window_frame = {
	active_titlebar_bg = "#1e1e2e",
	inactive_titlebar_bg = "#1e1e2e",
}


-- key bindings
config.keys = {

	{
		key = "d",
		mods = "ALT",
		action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "d",
		mods = "ALT|SHIFT",
		action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }),
	},
	{
		key = "k",
		mods = "ALT",
		action = wezterm.action.SendString("clear\n"),
	},
}

return config
