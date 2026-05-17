local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

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

config.initial_cols = 100
config.initial_rows = 30

-- Appearance
config.color_scheme = "tokyonight_night"
-- Transparent windows are expensive on GNOME/X11 and can make the whole window
-- lag while dragging/resizing because the compositor must blend every frame.
config.window_background_opacity = 0.95
config.window_decorations = 'TITLE | RESIZE'
config.scrollback_lines = 5000

-- Performance: keep rendering predictable while moving/resizing windows.
config.max_fps = 60
config.animation_fps = 1

-- Avoid WebGPU/adapter switching glitches on hybrid Intel/NVIDIA laptops.
-- OpenGL is usually smoother for X11 window moves under GNOME/Mutter.
config.front_end = 'OpenGL'

config.colors = {
    background = "#000000",
    cursor_bg = "#7aa2f7",
    cursor_fg = "#1a1b26",
    cursor_border = "#7aa2f7",
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
config.inactive_pane_hsb = {
    saturation = 0.7,
    brightness = 0.6,
}

-- =============================================================================
-- Helper: spawn jcode in a split pane
-- =============================================================================
local function jcode_split(direction, percent)
    return act.SplitPane {
        direction = direction,
        size = { Percent = percent or 50 },
        command = wezterm.action_callback(function(window, pane)
            -- no-op: will be handled by SpawnCommandInNewPane
        end),
    }
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
        action = act.SplitPane {
            direction = 'Right',
            size = { Percent = 50 },
            command = { args = { 'jcode' } },
        },
    },
    {
        key = 'j', mods = 'LEADER|SHIFT',
        action = act.SplitPane {
            direction = 'Down',
            size = { Percent = 40 },
            command = { args = { 'jcode' } },
        },
    },
    {
        key = 'n', mods = 'LEADER',
        action = act.SpawnCommandInNewTab {
            args = { 'jcode' },
        },
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
                args = { 'jcode' },
            }
            -- Split bottom-left -> jcode agent 3
            pane:split {
                direction = 'Bottom',
                size = 0.5,
                args = { 'jcode' },
            }
            -- Split bottom-right -> jcode agent 4
            right_pane:split {
                direction = 'Bottom',
                size = 0.5,
                args = { 'jcode' },
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
                args = { 'jcode' },
            }
        end),
    },
    {
        key = '3', mods = 'LEADER',
        action = wezterm.action_callback(function(window, pane)
            local p2 = pane:split {
                direction = 'Right',
                size = 0.66,
                args = { 'jcode' },
            }
            p2:split {
                direction = 'Right',
                size = 0.5,
                args = { 'jcode' },
            }
        end),
    },

    -- Resume last session in a split: Ctrl+A then r
    {
        key = 'r', mods = 'LEADER',
        action = act.SplitPane {
            direction = 'Right',
            size = { Percent = 50 },
            command = { args = { 'jcode', '--resume' } },
        },
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
