vim.opt.rtp:prepend(vim.fn.expand("~/.config/nvim"))

local bufnr = vim.api.nvim_create_buf(true, false)
vim.api.nvim_set_current_buf(bufnr)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "function hello() {",
  "  print('hello')",
  "}",
})

local mcp = require("config.mcp")
local ai = require("jcode_ai")

local preview = mcp.propose_edit(bufnr, 1, 3, "function hello_world() {\\n  print('hello world!')\\n}")
local preview_status = ai.preview_status(bufnr)
local after_preview = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

local reject = mcp.reject_edit(bufnr)
local after_reject = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

mcp.propose_edit(bufnr, 1, 3, "function hello_world() {\\n  print('hello world!')\\n}")
local accept = mcp.accept_edit(bufnr)
local after_accept = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

local expected_original = [[function hello() {
  print('hello')
}]]

local expected_applied = [[function hello_world() {
  print('hello world!')
}]]

print("-------------------- TEST RESULT --------------------")
print("preview.active", preview.active)
print("preview_status.active", preview_status.active)
print("reject.rejected", reject.rejected)
print("accept.applied", accept.applied)
print("-----------------------------------------------------")

if preview.active
  and preview_status.active
  and reject.rejected
  and accept.applied
  and after_preview == expected_original
  and after_reject == expected_original
  and after_accept == expected_applied then
  print("SUCCESS: Preview, reject, and accept behaviors match expected output!")
  vim.cmd("qall!")
else
  print("FAILURE: AI edit workflow did not match expected behavior!")
  print("after_preview:\n" .. after_preview)
  print("after_reject:\n" .. after_reject)
  print("after_accept:\n" .. after_accept)
  vim.cmd("cquit")
end
