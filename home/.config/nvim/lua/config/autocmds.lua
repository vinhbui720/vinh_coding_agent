-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Automatically open a Unix domain socket server for MCP client connections
local socket_path = "/tmp/nvim.pipe"
if vim.fn.serverlist()[1] == nil or not vim.tbl_contains(vim.fn.serverlist(), socket_path) then
  pcall(vim.fn.serverstart, socket_path)
end

-- Force OSC52 clipboard over SSH (Bypasses linux clipboard issues)
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function()
    -- Copy when yanked via operator 'y' OR when writing to clipboard registers '+' or '*'
    if vim.v.event.operator == 'y' or vim.v.event.regname == '+' or vim.v.event.regname == '*' then
      require('vim.ui.clipboard.osc52').copy('+')(vim.v.event.regcontents)
    end
  end,
})
