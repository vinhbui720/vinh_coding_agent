vim.opt.rtp:prepend(vim.fn.expand("~/.config/nvim"))

local ai = require("jcode_ai")
local t = ai._test

assert(t and t.send_prompt_async and t.ask_agent_edit_async and t.ask_agent_async, "missing async test hooks")

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
dropdown.pick(2)

local input_value
local input = t.open_inline_input("Ask AI edit", "Describe the change you want", function(value)
  input_value = value
end)
local input_lines_before = vim.api.nvim_buf_get_lines(input.buf, 0, -1, false)
local input_maps = vim.api.nvim_buf_get_keymap(input.buf, "i")
local has_input_tab = false
for _, map in ipairs(input_maps) do
  if string.lower(map.lhs) == "<tab>" then
    has_input_tab = true
  end
end
vim.api.nvim_buf_set_lines(input.buf, 0, -1, false, { "> rename value to total" })
input.submit()

local async_calls = {}
local old_system = vim.system
local response_win_before = #vim.api.nvim_list_wins()
vim.system = function(cmd, opts, on_exit)
  table.insert(async_calls, cmd)
  local resumed = false
  for i = 1, #cmd do
    if cmd[i] == "--resume" then
      resumed = true
      break
    end
  end
  local result = {
    code = 0,
    signal = 0,
    stdout = resumed
      and '{"session_id":"session_async_1","type":"assistant_final","text":"{\\"kind\\":\\"edit_batch\\",\\"summary\\":\\"fix\\",\\"edits\\":[{\\"start_line\\":1,\\"end_line\\":1,\\"replacement\\":\\"local total = 1\\"}]}"}\n'
      or '{"session_id":"session_async_2","type":"assistant_final","text":"async answer"}\n',
    stderr = "",
  }
  if on_exit then
    on_exit(result)
    return { wait = function() return result end }
  end
  return { wait = function() return result end }
end

local edit_done = false
local edit_result, edit_err
ai.ask_agent_edit_async("Fix this", { bufnr = bufnr, start_line = 1, end_line = 1 }, function(result, err)
  edit_result = result
  edit_err = err
  edit_done = true
end)
assert(vim.wait(1000, function() return edit_done end, 20), "expected async edit callback")

local ask_done = false
local ask_result
ai.ask_agent_async("Explain this", { bufnr = bufnr, start_line = 1, end_line = 1 }, function(result)
  ask_result = result
  ask_done = true
end)
assert(vim.wait(1000, function() return ask_done end, 20), "expected async ask callback")

vim.system = old_system
vim.cmd = old_cmd

local preview = ai.preview_status(bufnr)
local response_win_after = #vim.api.nvim_list_wins()
local ok = dropdown_lines[1]:match("Custom prompt")
  and dropdown_lines[2]:match("Fix the code")
  and dropdown_pick and dropdown_pick.prompt == "Fix the code on this line or selection."
  and input_lines_before[1] == "> "
  and has_input_tab
  and input_value == "rename value to total"
  and #async_calls == 2
  and edit_done and edit_result and edit_result.ok and edit_err == nil
  and ask_done and ask_result and ask_result.ok
  and preview.active
  and response_win_after > response_win_before

if ok then
  print("SUCCESS: Async inline prompt UI stays nonblocking and shows results as expected!")
  vim.cmd("qall!")
else
  print("FAILURE: Async inline prompt UI smoke test failed")
  print("dropdown_lines", vim.inspect(dropdown_lines))
  print("dropdown_pick", vim.inspect(dropdown_pick))
  print("input_lines_before", vim.inspect(input_lines_before))
  print("has_input_tab", has_input_tab)
  print("input_value", vim.inspect(input_value))
  print("async_calls", vim.inspect(async_calls))
  print("edit_done", edit_done, "edit_err", vim.inspect(edit_err), "edit_result", vim.inspect(edit_result))
  print("ask_done", ask_done, "ask_result", vim.inspect(ask_result))
  print("preview", vim.inspect(preview))
  print("response_win_before", response_win_before, "response_win_after", response_win_after)
  vim.cmd("cquit")
end
