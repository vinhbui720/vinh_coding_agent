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
local events = {}

for _, pattern in ipairs({
  "JcodeAIPreviewCreated",
  "JcodeAIPreviewAccepted",
  "JcodeAIPreviewRejected",
  "JcodeAIRequestCreated",
  "JcodeAIRequestTaken",
  "JcodeAIRequestResponded",
}) do
  vim.api.nvim_create_autocmd("User", {
    pattern = pattern,
    callback = function()
      events[pattern] = true
    end,
  })
end

local preview = mcp.propose_edit(bufnr, 1, 3, "function hello_world() {\\n  print('hello world!')\\n}")
local preview_status = ai.preview_status(bufnr)
local after_preview = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

local reject = mcp.reject_edit(bufnr)
local after_reject = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

mcp.propose_edit(bufnr, 1, 3, "function hello_world() {\\n  print('hello world!')\\n}")
local accept = mcp.accept_edit(bufnr)
local after_accept = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

local req = ai.create_request("rename animal words", { bufnr = bufnr, start_line = 1, end_line = 3, type = "edit_request" })
local taken = ai.take_request(req.id)
local responded = ai.respond_request(req.id, {
  message = "preview ready",
  preview_edit = {
    bufnr = bufnr,
    start_line = 1,
    end_line = 3,
    proposed_text = "function animal_world() {\\n  print('tiger world!')\\n}",
  },
})
local request_preview_active = ai.preview_status(bufnr).active
local request_accept = ai.accept_edit(bufnr)
local after_request_accept = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

local parsed_edit, parse_err = ai.parse_edit_response(vim.json.encode({
  kind = "edit_batch",
  summary = "rename hello function",
  edits = {
    {
      start_line = 1,
      end_line = 3,
      replacement = "function structured_world() {\\n  print('json world!')\\n}",
    },
  },
}), { bufnr = bufnr, start_line = 1, end_line = 3 })

local previewed_edit, preview_err = ai.preview_edit_response(vim.json.encode({
  kind = "edit_batch",
  summary = "structured preview",
  edits = {
    {
      start_line = 1,
      end_line = 3,
      replacement = "function structured_world() {\\n  print('json world!')\\n}",
    },
  },
}), { bufnr = bufnr, start_line = 1, end_line = 3 })
local structured_preview_active = ai.preview_status(bufnr).active
local structured_accept = ai.accept_edit(bufnr)
local after_structured_accept = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")

local expected_original = [[function hello() {
  print('hello')
}]]

local expected_applied = [[function hello_world() {
  print('hello world!')
}]]

local expected_request_applied = [[function animal_world() {
  print('tiger world!')
}]]

local expected_structured_applied = [[function structured_world() {
  print('json world!')
}]]

print("-------------------- TEST RESULT --------------------")
print("preview.active", preview.active)
print("preview_status.active", preview_status.active)
print("reject.rejected", reject.rejected)
print("accept.applied", accept.applied)
print("request.taken", taken and taken.status)
print("request.responded", responded and responded.status)
print("request.preview_active", request_preview_active)
print("request.accept.applied", request_accept.applied)
print("structured.parse.ok", parsed_edit ~= nil and parse_err == nil)
print("structured.preview.ok", previewed_edit ~= nil and preview_err == nil)
print("structured.accept.applied", structured_accept.applied)
print("-----------------------------------------------------")

if preview.active
  and preview_status.active
  and reject.rejected
  and accept.applied
  and taken and taken.status == "in_progress"
  and responded and responded.status == "answered"
  and request_preview_active
  and request_accept.applied
  and parsed_edit ~= nil
  and parse_err == nil
  and previewed_edit ~= nil
  and preview_err == nil
  and structured_preview_active
  and structured_accept.applied
  and after_preview == expected_original
  and after_reject == expected_original
  and after_accept == expected_applied then
  if after_request_accept ~= expected_request_applied then
    print("FAILURE: Request response preview did not apply expected output!")
    print("after_request_accept:\n" .. after_request_accept)
    vim.cmd("cquit")
  elseif not (
    events.JcodeAIPreviewCreated
    and events.JcodeAIPreviewAccepted
    and events.JcodeAIPreviewRejected
    and events.JcodeAIRequestCreated
    and events.JcodeAIRequestTaken
    and events.JcodeAIRequestResponded
  ) then
    print("FAILURE: Expected lifecycle User events were not all observed!")
    print(vim.inspect(events))
    vim.cmd("cquit")
  elseif after_structured_accept ~= expected_structured_applied then
    print("FAILURE: Structured edit protocol did not apply expected output!")
    print("after_structured_accept:\n" .. after_structured_accept)
    vim.cmd("cquit")
  else
    print("SUCCESS: Preview, structured edit protocol, request bridge, and lifecycle events match expected output!")
    vim.cmd("qall!")
  end
else
  print("FAILURE: AI edit workflow did not match expected behavior!")
  print("after_preview:\n" .. after_preview)
  print("after_reject:\n" .. after_reject)
  print("after_accept:\n" .. after_accept)
  vim.cmd("cquit")
end
