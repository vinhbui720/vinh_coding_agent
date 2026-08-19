-- Add ~/.config/nvim to runtime path so we can load config.mcp
vim.opt.rtp:prepend(vim.fn.expand("~/.config/nvim"))

-- Create a new test buffer
local bufnr = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
  "function hello() {",
  "  print('hello')",
  "}"
})

-- Load and run the propose_edit function
local mcp = require("config.mcp")
mcp.propose_edit(bufnr, 1, 3, "function hello_world() {\n  print('hello world!')\n}")

-- Fetch the updated buffer lines
local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
local result = table.concat(lines, "\n")

local expected = [[<<<<<<< Current
function hello() {
  print('hello')
}
=======
function hello_world() {
  print('hello world!')
}
>>>>>>> Proposed]]

print("-------------------- TEST RESULT --------------------")
print(result)
print("-----------------------------------------------------")

if result == expected then
  print("SUCCESS: Conflict markers match expected output!")
  vim.cmd("qall!")
else
  print("FAILURE: Output does not match expected!")
  vim.cmd("cquit") -- exit with code 1
end
