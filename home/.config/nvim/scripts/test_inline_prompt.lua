vim.opt.rtp:prepend(vim.fn.expand("~/.config/nvim"))

local ai = require("jcode_ai")
local t = ai._test

assert(t and t.send_prompt_async and t.ask_agent_edit_async and t.ask_agent_async, "missing async test hooks")
assert(t.open_feedback_tui and t.load_feedback_history, "missing feedback TUI hooks")

local history_path = vim.fn.stdpath("state") .. "/jcode_ai/feedback_history.json"
pcall(vim.fn.delete, history_path)

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

local feedback_submit
local feedback = t.open_feedback_tui("ask", 1, 1, function(value)
  feedback_submit = value
end)
local feedback_history_lines_before = vim.api.nvim_buf_get_lines(feedback.history_buf, 0, -1, false)
local feedback_input_lines_before = vim.api.nvim_buf_get_lines(feedback.input_buf, 0, -1, false)
vim.api.nvim_buf_set_lines(feedback.input_buf, 0, -1, false, { "> custom follow-up" })
feedback.submit()

local async_calls = {}
local old_system = vim.system
local response_win_before = #vim.api.nvim_list_wins()
vim.system = function(cmd, opts, on_exit)
  table.insert(async_calls, cmd)
  local full_prompt = cmd[#cmd]
  local is_edit = type(full_prompt) == "string" and full_prompt:find("return valid JSON only for an edit proposal", 1, true) ~= nil
  local result = {
    code = 0,
    signal = 0,
    stdout = is_edit
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

local history = t.load_feedback_history()
local feedback_after = t.open_feedback_tui("ask", 1, 1, function() end)
local feedback_history_lines_after = vim.api.nvim_buf_get_lines(feedback_after.history_buf, 0, -1, false)
feedback_after.close()

local preview = ai.preview_status(bufnr)
local response_win_after = #vim.api.nvim_list_wins()
local ok = dropdown_lines[1]:match("Custom prompt")
  and dropdown_lines[2]:match("Fix the code")
  and dropdown_pick and dropdown_pick.prompt == "Fix the code on this line or selection."
  and feedback_history_lines_before[4] and feedback_history_lines_before[4]:match("No history yet")
  and feedback_input_lines_before[1] == "> "
  and feedback_submit == "custom follow-up"
  and #async_calls == 2
  and edit_done and edit_result and edit_result.ok and edit_err == nil
  and ask_done and ask_result and ask_result.ok and ask_result.text == "async answer"
  and preview.active
  and history[1] and history[1].prompt == "Explain this"
  and history[1].response == "async answer"
  and history[2] and history[2].prompt == "Fix this"
  and feedback_history_lines_after[4] and feedback_history_lines_after[4]:match("Explain this")

if ok then
  print("SUCCESS: Feedback TUI history, async prompt flow, and response rendering behave as expected!")
  vim.cmd("qall!")
else
  print("FAILURE: Feedback TUI smoke test failed")
  print("dropdown_lines", vim.inspect(dropdown_lines))
  print("dropdown_pick", vim.inspect(dropdown_pick))
  print("feedback_history_lines_before", vim.inspect(feedback_history_lines_before))
  print("feedback_input_lines_before", vim.inspect(feedback_input_lines_before))
  print("feedback_submit", vim.inspect(feedback_submit))
  print("async_calls", vim.inspect(async_calls))
  print("edit_done", edit_done, "edit_err", vim.inspect(edit_err), "edit_result", vim.inspect(edit_result))
  print("ask_done", ask_done, "ask_result", vim.inspect(ask_result))
  print("history", vim.inspect(history))
  print("feedback_history_lines_after", vim.inspect(feedback_history_lines_after))
  print("preview", vim.inspect(preview))
  print("response_win_before", response_win_before, "response_win_after", response_win_after)
  vim.cmd("cquit")
end
