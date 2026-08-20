local M = {}

function M.propose_edit(bufnr, start_line, end_line, proposed_text)
  return require("jcode_ai").preview_edit(bufnr, start_line, end_line, proposed_text)
end

function M.accept_edit(bufnr)
  return require("jcode_ai").accept_edit(bufnr)
end

function M.reject_edit(bufnr)
  return require("jcode_ai").reject_edit(bufnr)
end

function M.preview_status(bufnr)
  return require("jcode_ai").preview_status(bufnr)
end

return M
