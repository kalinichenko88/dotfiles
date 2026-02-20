local wezterm = require('wezterm')

local function mode_for_appearance(appearance)
  if appearance:find('Dark') then
    return 'dark'
  else
    return 'light'
  end
end

local function delta_theme_for_mode(mode)
  if mode == 'dark' then
    return 'OneHalfDark'
  else
    return 'OneHalfLight'
  end
end

local function scheme_for_appearance(appearance)
  if appearance:find('Dark') then
    return 'OneDark (base16)'
  else
    return 'One Light (base16)'
  end
end

local config = wezterm.config_builder()
local act = wezterm.action

-- Rendering
config.front_end = 'WebGpu'
config.max_fps = 120

-- Font
config.font = wezterm.font_with_fallback({
  { family = 'Monaco', weight = 'DemiBold' },
  'Menlo',
})
config.font_size = 13.0
config.line_height = 1.2
config.freetype_load_flags = 'NO_HINTING'

-- Colors
local appearance = (wezterm.gui and wezterm.gui.get_appearance()) or 'Dark'
local mode = mode_for_appearance(appearance)
config.color_scheme = scheme_for_appearance(appearance)
config.set_environment_variables = {
  BAT_THEME = delta_theme_for_mode(mode),
  DELTA_THEME_MODE = mode,
}

-- UI
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'
config.window_padding = { left = 10, right = 10, top = 40, bottom = 8 }
config.window_frame = {
  font_size = 16.0,
}

-- Cursor
config.default_cursor_style = 'BlinkingBar'
config.cursor_blink_rate = 600

-- Behavior
config.scrollback_lines = 10000

-- macOS
config.native_macos_fullscreen_mode = true

-- Window
config.window_background_opacity = 1.0
config.macos_window_background_blur = 0
config.inactive_pane_hsb = {
  saturation = 0.9,
  brightness = 0.9,
}
config.hyperlink_rules = wezterm.default_hyperlink_rules()
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelection('ClipboardAndPrimarySelection'),
  },
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CMD',
    action = act.OpenLinkAtMouseCursor,
  },
}

-- Keybindings
config.keys = {
  {
    key = '|',
    mods = 'CMD|SHIFT',
    action = act.Multiple({
      act.SplitPane({
        direction = 'Right',
        size = { Percent = 70 },
      }),
      act.SplitPane({
        direction = 'Down',
        size = { Percent = 15 },
      }),
    }),
  },
  {
    key = 'RightArrow',
    mods = 'CMD|SHIFT',
    action = act.SplitPane({ direction = 'Right' }),
  },
  {
    key = 'DownArrow',
    mods = 'CMD|SHIFT',
    action = act.SplitPane({ direction = 'Down' }),
  },
  {
    key = 'x',
    mods = 'CMD|SHIFT',
    action = act.CloseCurrentPane({ confirm = true }),
  },
  {
    key = 'p',
    mods = 'CMD',
    action = act.ActivateCommandPalette,
  },
}

-- Tab title: always show current directory name
wezterm.on('format-tab-title', function(tab)
  local pane = tab.active_pane
  local cwd = pane.current_working_dir
  if cwd then
    local path = cwd.file_path or tostring(cwd)
    local dir = path:match('([^/]+)/?$') or path
    return ' ' .. dir .. ' '
  end
end)

-- Dynamic color scheme switching
wezterm.on('window-config-reloaded', function(window)
  local overrides = window:get_config_overrides() or {}
  local scheme = scheme_for_appearance(window:get_appearance())
  if overrides.color_scheme ~= scheme then
    overrides.color_scheme = scheme
    window:set_config_overrides(overrides)
  end
end)

return config
