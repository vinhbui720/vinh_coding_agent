local M = {}

--- Propose a code change in the active buffer using git-style conflict markers.
--- @param bufnr number The buffer number (0 for active buffer)
--- @param start_line number The 1-indexed starting line number to replace
--- @param end_line number The 1-indexed ending line number to replace
--- @param proposed_text string The new code content proposed by the agent
function M.propose_edit(bufnr, start_line, end_line, proposed_text)
  bufnr = (bufnr == 0 or bufnr == nil) and vim.api.nvim_get_current_buf() or bufnr
  local s_idx = start_line - 1
  local e_idx = end_line

  -- Retrieve the original lines
  local original_lines = vim.api.nvim_buf_get_lines(bufnr, s_idx, e_idx, false)

  -- Build the conflict block lines
  local conflict_lines = { "<<<<<<< Current" }
  for _, line in ipairs(original_lines) do
    table.insert(conflict_lines, line)
  end
  table.insert(conflict_lines, "=======")
  for line in (proposed_text .. "\n"):gmatch("([^\n]*)\n") do
    table.insert(conflict_lines, line)
  end
  table.insert(conflict_lines, ">>>>>>> Proposed")

  -- Clean up trailing empty string from the string split
  if conflict_lines[#conflict_lines] == "" then
    table.remove(conflict_lines)
  end

  -- Write the conflict block to the buffer in memory
  vim.api.nvim_buf_set_lines(bufnr, s_idx, e_idx, false, conflict_lines)

  -- Refresh git-conflict plugin if it is installed/loaded
  local ok, git_conflict = pcall(require, "git-conflict")
  if ok then
    git_conflict.refresh(bufnr)
  end
end

return M
