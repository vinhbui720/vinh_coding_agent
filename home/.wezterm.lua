local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Enable inline image rendering used by Jcode Mermaid diagrams and image previews.
config.enable_kitty_graphics = true
-- Advertise a widely-supported 256-color terminal.  `TERM=wezterm` can make
-- some shells/apps lose colors when their terminfo lookup differs from WezTerm's.
config.term = 'xterm-256color'
config.set_environment_variables = {
    TERM = 'xterm-256color',
    JCODE_ENABLE_MERMAID = '1',
}

local function shell_escape(s)
    return wezterm.shell_quote_arg(s or '')
end

local function is_remote_pane(pane)
    local vars = pane:get_user_vars() or {}
    local host = vars.WEZTERM_HOST or ''
    local user = vars.WEZTERM_USER or ''
    local cwd_url = pane:get_current_working_dir()
    local cwd = nil

    if cwd_url and cwd_url.file_path then
        cwd = cwd_url.file_path
    end

    if host == '' then
        return false, user, host, cwd
    end

    local local_host = wezterm.hostname()
    return host ~= local_host and host ~= 'localhost' and host ~= '127.0.0.1', user, host, cwd
end

local function do_split_same_place(window, pane, direction)
    local ok, err = pcall(function()
        local remote, user, host, cwd = is_remote_pane(pane)
        local split = nil

        if remote and host ~= '' then
            local target = host
            if user ~= '' then
                target = string.format('%s@%s', user, host)
            end

            local remote_cmd = 'exec ${SHELL:-/bin/bash} -il'
            if cwd and cwd ~= '' then
                remote_cmd = string.format('cd %s && %s', shell_escape(cwd), remote_cmd)
            end

            split = act.SplitPane {
                direction = direction,
                size = { Percent = 50 },
                command = {
                    args = { 'ssh', '-t', target, remote_cmd },
                },
            }
        else
            local local_cmd = 'exec ${SHELL:-/bin/bash} -il'
            if cwd and cwd ~= '' then
                local_cmd = string.format('cd %s && %s', shell_escape(cwd), local_cmd)
            end
            split = act.SplitPane {
                direction = direction,
                size = { Percent = 50 },
                command = {
                    args = { 'bash', '-lc', local_cmd },
                },
            }
        end

        window:perform_action(split, pane)
    end)
    if not ok then
        window:toast_notification('WezTerm split error', tostring(err), nil, 4000)
    end
end

wezterm.on('jcode-split-right-same-place', function(window, pane)
    do_split_same_place(window, pane, 'Right')
end)

wezterm.on('jcode-split-down-same-place', function(window, pane)
    do_split_same_place(window, pane, 'Down')
end)

-- =============================================================================
-- General UI & Font Settings
-- =============================================================================
config.font = wezterm.font("BlexMono Nerd Font Mono")
config.font_size = 13.0
config.line_height = 1.2
-- Jcode/Kitty image protocol uses private-use placeholder glyphs (e.g. U+10eeee).
-- WezTerm may warn that no font contains them even though the image protocol handles them.
config.warn_about_missing_glyphs = false

config.initial_cols = 100
config.initial_rows = 30

-- Appearance
-- Use the built-in WezTerm scheme name.  The old `tokyonight_night` name is
-- common in other tools but is not the canonical WezTerm scheme name.
config.color_scheme = "Tokyo Night"
-- Transparent windows are expensive on GNOME/X11 and can make the whole window
-- lag while dragging/resizing because the compositor must blend every frame.
config.window_background_opacity = 1.0
config.window_decorations = 'TITLE | RESIZE'
config.scrollback_lines = 5000

-- Performance: keep rendering predictable while moving/resizing windows.
config.max_fps = 30
config.animation_fps = 1
config.cursor_blink_rate = 0
config.enable_scroll_bar = false

-- Avoid WebGPU/adapter switching glitches on hybrid Intel/NVIDIA laptops.
-- OpenGL is usually smoother for X11 window moves under GNOME/Mutter.
config.front_end = 'OpenGL'

config.colors = {
    background = "#000000",
    foreground = "#c0caf5",
    cursor_bg = "#7aa2f7",
    cursor_fg = "#1a1b26",
    cursor_border = "#7aa2f7",
    ansi = {
        "#15161e", -- black
        "#f7768e", -- red
        "#9ece6a", -- green
        "#e0af68", -- yellow
        "#7aa2f7", -- blue
        "#bb9af7", -- magenta
        "#7dcfff", -- cyan
        "#a9b1d6", -- white
    },
    brights = {
        "#414868", -- bright black
        "#f7768e", -- bright red
        "#9ece6a", -- bright green
        "#e0af68", -- bright yellow
        "#7aa2f7", -- bright blue
        "#bb9af7", -- bright magenta
        "#7dcfff", -- bright cyan
        "#c0caf5", -- bright white
    },
    -- Pane split border colors
    split = "#7aa2f7",
}

-- =============================================================================
-- Mouse pane resizing
-- =============================================================================
-- WezTerm 20240203 does not support dragging pane split borders directly.
-- These bindings provide mouse-based resizing:
--   Ctrl+Shift + mouse wheel       -> resize the active pane left/right
--   Ctrl+Alt+Shift + mouse wheel   -> resize the active pane up/down
config.mouse_bindings = {
    {
        event = { Down = { streak = 1, button = { WheelUp = 1 } } },
        mods = 'CTRL|SHIFT',
        action = act.AdjustPaneSize { 'Left', 3 },
    },
    {
        event = { Down = { streak = 1, button = { WheelDown = 1 } } },
        mods = 'CTRL|SHIFT',
        action = act.AdjustPaneSize { 'Right', 3 },
    },
    {
        event = { Down = { streak = 1, button = { WheelUp = 1 } } },
        mods = 'CTRL|ALT|SHIFT',
        action = act.AdjustPaneSize { 'Up', 3 },
    },
    {
        event = { Down = { streak = 1, button = { WheelDown = 1 } } },
        mods = 'CTRL|ALT|SHIFT',
        action = act.AdjustPaneSize { 'Down', 3 },
    },
}

-- =============================================================================
-- Tab Bar (enable for multi-agent visibility)
-- =============================================================================
config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = false
config.tab_bar_at_bottom = true
config.tab_max_width = 32

config.colors.tab_bar = {
    background = "#0a0a0a",
    active_tab = {
        bg_color = "#1a1b26",
        fg_color = "#7aa2f7",
        intensity = "Bold",
    },
    inactive_tab = {
        bg_color = "#0a0a0a",
        fg_color = "#565f89",
    },
    inactive_tab_hover = {
        bg_color = "#1a1b26",
        fg_color = "#c0caf5",
    },
    new_tab = {
        bg_color = "#0a0a0a",
        fg_color = "#565f89",
    },
    new_tab_hover = {
        bg_color = "#1a1b26",
        fg_color = "#7aa2f7",
    },
}

-- =============================================================================
-- Inactive pane dimming (helps distinguish active agent)
-- =============================================================================
-- Inactive pane dimming costs extra compositor work on GNOME/X11; keep panes full-bright for responsiveness.
config.inactive_pane_hsb = {
    saturation = 1.0,
    brightness = 1.0,
}

local jcode_args = { 'env', 'JCODE_NO_AUTO_UPDATE=1', 'jcode', '--quiet', '--no-update', '-p', 'openai', '-m', 'gpt-5.4' }

local function pane_cwd(pane)
    local cwd_url = pane:get_current_working_dir()
    if cwd_url and cwd_url.file_path and cwd_url.file_path ~= '' then
        return cwd_url.file_path
    end
    return nil
end

local function split_jcode_from_pane(pane, direction, size)
    pane:split {
        direction = direction,
        size = size,
        cwd = pane_cwd(pane),
        args = jcode_args,
    }
end

local function spawn_jcode_tab_from_pane(window, pane, extra_args)
    local args = jcode_args
    if extra_args then
        args = {}
        for _, value in ipairs(jcode_args) do table.insert(args, value) end
        for _, value in ipairs(extra_args) do table.insert(args, value) end
    end
    window:perform_action(act.SpawnCommandInNewTab {
        cwd = pane_cwd(pane),
        args = args,
    }, pane)
end

-- =============================================================================
-- Keybindings
-- =============================================================================
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1500 }

config.keys = {
    -- =========================================================================
    -- Pane Management (basic)
    -- =========================================================================
    { key = 'w', mods = 'CTRL',       action = act.CloseCurrentPane { confirm = false } },
    { key = 'd', mods = 'CTRL',       action = act.EmitEvent 'jcode-split-right-same-place' },
    { key = 'D', mods = 'CTRL|SHIFT', action = act.EmitEvent 'jcode-split-down-same-place' },

    -- =========================================================================
    -- Jcode Agent Splits  (LEADER + key)
    --   Ctrl+A then j  -> split right with jcode
    --   Ctrl+A then J  -> split bottom with jcode
    --   Ctrl+A then n  -> new tab with jcode
    --   Ctrl+A then 1-4 -> spawn numbered agent splits
    -- =========================================================================
    {
        key = 'j', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            split_jcode_from_pane(pane, 'Right', 0.5)
        end),
    },
    {
        key = 'j', mods = 'LEADER|SHIFT',
        action = wezterm.action_callback(function(window, pane)
            split_jcode_from_pane(pane, 'Bottom', 0.4)
        end),
    },
    {
        key = 'n', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            spawn_jcode_tab_from_pane(window, pane)
        end),
    },

    -- Spawn multiple agent grid: Ctrl+A then g
    -- Creates a 2x2 grid of jcode agents
    {
        key = 'g', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            -- Split right -> jcode agent 2
            local right_pane = pane:split {
                direction = 'Right',
                size = 0.5,
                cwd = pane_cwd(pane),
                args = jcode_args,
            }
            -- Split bottom-left -> jcode agent 3
            pane:split {
                direction = 'Bottom',
                size = 0.5,
                cwd = pane_cwd(pane),
                args = jcode_args,
            }
            -- Split bottom-right -> jcode agent 4
            right_pane:split {
                direction = 'Bottom',
                size = 0.5,
                cwd = pane_cwd(pane),
                args = jcode_args,
            }
        end),
    },

    -- Quick split: Ctrl+A then 2/3 for 2 or 3 vertical jcode panes
    {
        key = '2', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            pane:split {
                direction = 'Right',
                size = 0.5,
                cwd = pane_cwd(pane),
                args = jcode_args,
            }
        end),
    },
    {
        key = '3', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local p2 = pane:split {
                direction = 'Right',
                size = 0.66,
                cwd = pane_cwd(pane),
                args = jcode_args,
            }
            p2:split {
                direction = 'Right',
                size = 0.5,
                cwd = pane_cwd(pane),
                args = jcode_args,
            }
        end),
    },

    -- Resume last session in a split: Ctrl+A then r
    {
        key = 'r', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local args = {}
            for _, value in ipairs(jcode_args) do table.insert(args, value) end
            table.insert(args, '--resume')
            pane:split {
                direction = 'Right',
                size = 0.5,
                cwd = pane_cwd(pane),
                args = args,
            }
        end),
    },

    -- =========================================================================
    -- Pane Navigation (CTRL + Arrows)
    -- =========================================================================
    { key = 'LeftArrow',  mods = 'CTRL', action = act.ActivatePaneDirection 'Left' },
    { key = 'RightArrow', mods = 'CTRL', action = act.ActivatePaneDirection 'Right' },
    { key = 'UpArrow',    mods = 'CTRL', action = act.ActivatePaneDirection 'Up' },
    { key = 'DownArrow',  mods = 'CTRL', action = act.ActivatePaneDirection 'Down' },

    -- Alt+h/j/k/l pane navigation (vim-style, won't conflict with jcode workspace keys)
    { key = 'h', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left' },
    { key = 'l', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
    { key = 'k', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up' },
    { key = 'j', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down' },

    -- =========================================================================
    -- Pane Zoom (toggle maximize a single pane)
    -- =========================================================================
    { key = 'z', mods = 'LEADER',   action = act.TogglePaneZoomState },
    { key = 'z', mods = 'CTRL|SHIFT', action = act.TogglePaneZoomState },

    -- =========================================================================
    -- Tab Navigation
    -- =========================================================================
    { key = 'Tab',   mods = 'CTRL',       action = act.ActivateTabRelative(1) },
    { key = 'Tab',   mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
    { key = '1',     mods = 'ALT',        action = act.ActivateTab(0) },
    { key = '2',     mods = 'ALT',        action = act.ActivateTab(1) },
    { key = '3',     mods = 'ALT',        action = act.ActivateTab(2) },
    { key = '4',     mods = 'ALT',        action = act.ActivateTab(3) },
    { key = '5',     mods = 'ALT',        action = act.ActivateTab(4) },

    -- =========================================================================
    -- Utility
    -- =========================================================================
    { key = 'k',     mods = 'CTRL',  action = act.SendString 'clear\n' },
    { key = 'Enter', mods = 'ALT',   action = act.ToggleFullScreen },
    { key = 'F2',    mods = 'NONE',  action = wezterm.action_callback(function(window, pane)
        wezterm.run_child_process { '/home/vinh/bin/jcode-stop-tts' }
    end) },

    -- Enter Resize Mode (CTRL+SHIFT+R)
    {
        key = 'R', mods = 'CTRL|SHIFT',
        action = act.ActivateKeyTable {
            name = 'resize_mode',
            one_shot = false,
        },
    },

    -- =========================================================================
    -- Close all panes except current (Ctrl+A then o)
    -- =========================================================================
    {
        key = 'o', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local tab = pane:tab()
            local panes = tab:panes()
            for _, p in ipairs(panes) do
                if p:pane_id() ~= pane:pane_id() then
                    window:perform_action(act.CloseCurrentPane { confirm = false }, p)
                end
            end
        end),
    },

    -- =========================================================================
    -- Broadcast input to all panes (Ctrl+A then b) - useful for multi-agent
    -- =========================================================================
    {
        key = 'b', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local tab = pane:tab()
            local is_zoomed = tab:get_pane_direction('Left') == nil
                and tab:get_pane_direction('Right') == nil
            wezterm.log_info('Broadcast toggle - not yet implemented natively, use wezterm cli send-text')
        end),
    },
}

-- =============================================================================
-- Key Tables (Special Modes)
-- =============================================================================
config.key_tables = {
    resize_mode = {
        { key = 'LeftArrow',  action = act.AdjustPaneSize { 'Left', 3 } },
        { key = 'RightArrow', action = act.AdjustPaneSize { 'Right', 3 } },
        { key = 'UpArrow',    action = act.AdjustPaneSize { 'Up', 3 } },
        { key = 'DownArrow',  action = act.AdjustPaneSize { 'Down', 3 } },
        { key = 'h',          action = act.AdjustPaneSize { 'Left', 3 } },
        { key = 'l',          action = act.AdjustPaneSize { 'Right', 3 } },
        { key = 'k',          action = act.AdjustPaneSize { 'Up', 3 } },
        { key = 'j',          action = act.AdjustPaneSize { 'Down', 3 } },
        { key = 'Escape',     action = 'PopKeyTable' },
        { key = 'Enter',      action = 'PopKeyTable' },
    },
}

-- =============================================================================
-- Right-click status with pane count (useful for multi-agent awareness)
-- =============================================================================
wezterm.on('update-right-status', function(window, pane)
    local tab = pane:tab()
    local pane_count = #tab:panes()
    local agent_indicator = ''
    if pane_count > 1 then
        agent_indicator = wezterm.format {
            { Foreground = { Color = '#7aa2f7' } },
            { Text = string.format(' Panes: %d ', pane_count) },
        }
    end

    window:set_right_status(wezterm.format {
        { Foreground = { Color = '#565f89' } },
        { Text = wezterm.strftime ' %H:%M ' },
    } .. agent_indicator)
end)

return config
