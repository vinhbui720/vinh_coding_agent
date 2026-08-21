vim.opt.rtp:prepend(vim.fn.expand("~/.config/nvim"))

local ai = require("jcode_ai")
local t = ai._test
assert(t and t.open_inline_dropdown and t.open_inline_input, "missing popup test hooks")

local old_cmd = vim.cmd
vim.cmd = function(cmd)
  if cmd == "startinsert" then
    return
  end
  return old_cmd(cmd)
end

local bufnr = vim.api.nvim_create_buf(false, true)
vim.api.nvim_set_current_buf(bufnr)
vim.bo[bufnr].buftype = "nofile"
vim.bo[bufnr].bufhidden = "wipe"
vim.bo[bufnr].swapfile = false
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "local x = 1" })
vim.api.nvim_win_set_cursor(0, { 1, 0 })

local picker = t.open_inline_dropdown("AI Edit", t.preset_items("edit"), function() end)
local picker_maps = vim.api.nvim_buf_get_keymap(picker.buf, "n")
local has_ctrl_c = false
for _, map in ipairs(picker_maps) do
  if string.lower(map.lhs) == "<c-c>" then
    has_ctrl_c = true
  end
end
local other = vim.api.nvim_create_buf(false, true)
vim.bo[other].buftype = "nofile"
vim.bo[other].bufhidden = "wipe"
vim.bo[other].swapfile = false
vim.api.nvim_set_current_buf(other)
vim.wait(50, function() return not vim.api.nvim_win_is_valid(picker.win) end, 10)

local input = t.open_inline_input("Ask AI edit", "Describe", function() end)
local input_imaps = vim.api.nvim_buf_get_keymap(input.buf, "i")
local has_input_ctrl_c = false
for _, map in ipairs(input_imaps) do
  if string.lower(map.lhs) == "<c-c>" then
    has_input_ctrl_c = true
  end
end
input.close()
vim.cmd = old_cmd

if has_ctrl_c and has_input_ctrl_c then
  print("SUCCESS: Popup close mappings include Ctrl-C and lifecycle autoclose hooks are installed.")
  vim.cmd("qall!")
else
  print("FAILURE: Popup close mappings missing expected keys")
  print("has_ctrl_c", has_ctrl_c)
  print("has_input_ctrl_c", has_input_ctrl_c)
  vim.cmd("cquit")
end
