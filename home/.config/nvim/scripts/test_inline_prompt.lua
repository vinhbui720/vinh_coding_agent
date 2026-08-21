vim.opt.rtp:prepend(vim.fn.expand("~/.config/nvim"))

local ai = require("jcode_ai")
local t = ai._test

assert(t and t.send_prompt_async and t.ask_agent_edit_async and t.ask_agent_async, "missing async test hooks")
assert(t.open_feedback_tui and t.open_inline_input and t.open_status_popup and t.load_feedback_history, "missing status popup hooks")

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

local inline_submit
local inline_input = t.open_inline_input("Ask prompt", "", function(value)
  inline_submit = value
end)
vim.api.nvim_buf_set_lines(inline_input.buf, 0, -1, false, { "> custom follow-up" })
inline_input.submit()

local status_popup = t.open_feedback_tui("ask")
local status_lines_before = vim.api.nvim_buf_get_lines(status_popup.history_buf, 0, -1, false)
status_popup.close()

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
  local proc = {
    wait = function() return result end,
    kill = function() end,
  }
  if on_exit then
    vim.schedule(function()
      on_exit(result)
    end)
  end
  return proc
end

local edit_popup = t.open_status_popup("edit")
local edit_done = false
local edit_result, edit_err
ai.ask_agent_edit_async("Fix this", { bufnr = bufnr, start_line = 1, end_line = 1, tui = edit_popup }, function(result, err)
  edit_result = result
  edit_err = err
  edit_done = true
end)
assert(vim.wait(1000, function() return edit_done end, 20), "expected async edit callback")
local edit_popup_lines = vim.api.nvim_buf_get_lines(edit_popup.history_buf, 0, -1, false)
edit_popup.close()

local ask_popup = t.open_status_popup("ask")
local ask_done = false
local ask_result
ai.ask_agent_async("Explain this", { bufnr = bufnr, start_line = 1, end_line = 1, tui = ask_popup }, function(result)
  ask_result = result
  ask_done = true
end)
assert(vim.wait(1000, function() return ask_done end, 20), "expected async ask callback")
local ask_popup_lines = vim.api.nvim_buf_get_lines(ask_popup.history_buf, 0, -1, false)
ask_popup.close()

vim.system = old_system
vim.cmd = old_cmd

local history = t.load_feedback_history()
local feedback_after = t.open_feedback_tui("ask")
local feedback_history_lines_after = vim.api.nvim_buf_get_lines(feedback_after.history_buf, 0, -1, false)
feedback_after.close()

local preview = ai.preview_status(bufnr)
local response_win_after = #vim.api.nvim_list_wins()
local ok = dropdown_lines[1]:match("Custom prompt")
  and dropdown_lines[2]:match("Fix the code")
  and dropdown_pick and dropdown_pick.prompt == "Fix the code on this line or selection."
  and inline_submit == "custom follow-up"
  and status_lines_before[1] and status_lines_before[1]:match("%[ASK%] idle")
  and status_lines_before[4] and status_lines_before[4]:match("%[none yet%]")
  and status_lines_before[5] and status_lines_before[5]:match("No request yet")
  and #async_calls == 2
  and edit_done and edit_result and edit_result.ok and edit_err == nil
  and edit_popup_lines[1] and edit_popup_lines[1]:match("%[EDIT%] completed")
  and edit_popup_lines[4] and edit_popup_lines[4]:match("Fix this")
  and ask_done and ask_result and ask_result.ok and ask_result.text == "async answer"
  and ask_popup_lines[1] and ask_popup_lines[1]:match("%[ASK%] completed")
  and ask_popup_lines[5] and ask_popup_lines[5]:match("Request completed")
  and ask_popup_lines[6] and ask_popup_lines[6]:match("async answer")
  and preview.active
  and history[1] and history[1].prompt == "Explain this"
  and history[1].response == "async answer"
  and history[2] and history[2].prompt == "Fix this"
  and feedback_history_lines_after[9] and feedback_history_lines_after[9]:match("Explain this")
  and response_win_after == response_win_before

if ok then
  print("SUCCESS: Primary inline composer plus secondary status popup behave as expected!")
  vim.cmd("qall!")
else
  print("FAILURE: Status popup smoke test failed")
  print("dropdown_lines", vim.inspect(dropdown_lines))
  print("dropdown_pick", vim.inspect(dropdown_pick))
  print("inline_submit", vim.inspect(inline_submit))
  print("status_lines_before", vim.inspect(status_lines_before))
  print("async_calls", vim.inspect(async_calls))
  print("edit_done", edit_done, "edit_err", vim.inspect(edit_err), "edit_result", vim.inspect(edit_result))
  print("edit_popup_lines", vim.inspect(edit_popup_lines))
  print("ask_done", ask_done, "ask_result", vim.inspect(ask_result))
  print("ask_popup_lines", vim.inspect(ask_popup_lines))
  print("history", vim.inspect(history))
  print("feedback_history_lines_after", vim.inspect(feedback_history_lines_after))
  print("preview", vim.inspect(preview))
  print("response_win_before", response_win_before, "response_win_after", response_win_after)
  vim.cmd("cquit")
end
