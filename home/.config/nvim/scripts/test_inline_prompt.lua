vim.opt.rtp:prepend(vim.fn.expand("~/.config/nvim"))

local ai = require("jcode_ai")
local t = ai._test

assert(t, "missing jcode_ai._test helpers")
assert(t.open_inline_dropdown, "missing open_inline_dropdown test hook")
assert(t.open_inline_input, "missing open_inline_input test hook")
assert(t.show_inline_hint, "missing show_inline_hint test hook")
assert(t.clear_inline_hint, "missing clear_inline_hint test hook")
assert(t.run_prompt_action, "missing run_prompt_action test hook")
assert(t.ui_ns, "missing inline ui namespace hook")

local bufnr = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "local value = 1",
  "return value",
})
vim.api.nvim_win_set_cursor(0, { 1, 0 })

local old_cmd = vim.cmd
vim.cmd = function(cmd)
  if cmd == "startinsert" then
    return
  end
  return old_cmd(cmd)
end

local dropdown_pick
local dropdown = t.open_inline_dropdown("AI Edit", t.preset_items("edit"), function(item)
  dropdown_pick = item
end)
local dropdown_lines = vim.api.nvim_buf_get_lines(dropdown.buf, 0, -1, false)
local dropdown_maps = vim.api.nvim_buf_get_keymap(dropdown.buf, "n")
local expected_dropdown_maps = {
  ["<tab>"] = false,
  ["<right>"] = false,
  ["<down>"] = false,
  ["<up>"] = false,
  ["<c-n>"] = false,
  ["<c-p>"] = false,
}
for _, map in ipairs(dropdown_maps) do
  local lhs = string.lower(map.lhs)
  if expected_dropdown_maps[lhs] ~= nil then
    expected_dropdown_maps[lhs] = true
  end
end

dropdown.pick(2)

local input_value
local input = t.open_inline_input("Ask AI edit", "Describe the change you want", function(value)
  input_value = value
end)
local input_maps = vim.api.nvim_buf_get_keymap(input.buf, "i")
local has_input_tab = false
for _, map in ipairs(input_maps) do
  if map.lhs == "<Tab>" then
    has_input_tab = true
  end
end
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { "> rename value to total" })
input.submit()

t.show_inline_hint(bufnr, 1, {
  { "AI", "Special" },
  { " Tab accept", "Comment" },
})
local marks_after_show = vim.api.nvim_buf_get_extmarks(bufnr, t.ui_ns, 0, -1, { details = true })
t.clear_inline_hint(bufnr)
local marks_after_clear = vim.api.nvim_buf_get_extmarks(bufnr, t.ui_ns, 0, -1, { details = true })

local edit_call
local ask_call
local notifications = {}
local old_edit = ai.ask_agent_edit
local old_ask = ai.ask_agent
local old_notify = vim.notify
ai.ask_agent_edit = function(prompt, opts)
  edit_call = { prompt = prompt, opts = opts }
  return { session_id = "sess_inline_test" }, nil
end
ai.ask_agent = function(prompt, opts)
  ask_call = { prompt = prompt, opts = opts }
  return { ok = true, text = "ok" }
end
vim.notify = function(message, level)
  table.insert(notifications, { message = message, level = level })
end

t.run_prompt_action("edit", "Fix this", 1, 2)
t.run_prompt_action("ask", "Explain this", 1, 1)

ai.ask_agent_edit = old_edit
ai.ask_agent = old_ask
vim.notify = old_notify
vim.cmd = old_cmd

local ok = dropdown_lines[1]:match("Custom prompt")
  and dropdown_lines[2]:match("Fix the code")
  and dropdown_pick ~= nil
  and dropdown_pick.prompt == "Fix the code on this line or selection."
  and has_input_tab
  and input_value == "rename value to total"
  and #marks_after_show >= 1
  and #marks_after_clear == 0
  and edit_call ~= nil
  and edit_call.prompt == "Fix this"
  and edit_call.opts.start_line == 1
  and edit_call.opts.end_line == 2
  and ask_call ~= nil
  and ask_call.prompt == "Explain this"
  and ask_call.opts.start_line == 1
  and ask_call.opts.end_line == 1
  and vim.tbl_contains(vim.tbl_values(expected_dropdown_maps), true)

for lhs, present in pairs(expected_dropdown_maps) do
  if not present then
    ok = false
    print("missing_dropdown_map", lhs)
  end
end

if ok and notifications[1] and notifications[1].message:match("AI preview ready from session sess_inline_test") then
  print("SUCCESS: Inline prompt dropdown, inline input, ghost hints, and prompt actions behave as expected!")
  vim.cmd("qall!")
else
  print("FAILURE: Inline prompt UI smoke test failed")
  print("dropdown_lines", vim.inspect(dropdown_lines))
  print("dropdown_pick", vim.inspect(dropdown_pick))
  print("has_input_tab", has_input_tab)
  print("input_value", vim.inspect(input_value))
  print("marks_after_show", #marks_after_show)
  print("marks_after_clear", #marks_after_clear)
  print("edit_call", vim.inspect(edit_call))
  print("ask_call", vim.inspect(ask_call))
  print("notifications", vim.inspect(notifications))
  vim.cmd("cquit")
end
