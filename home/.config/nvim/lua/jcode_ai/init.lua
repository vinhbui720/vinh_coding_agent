local M = {}

local ns = vim.api.nvim_create_namespace("jcode_ai_preview")

M._setup_done = false
M._state = {}

local function current_buf(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function decode_text(text)
  return (text or ""):gsub("\\n", "\n")
end

local function split_lines(text)
  return vim.split(decode_text(text), "\n", { plain = true })
end

local function state_for(bufnr)
  return M._state[current_buf(bufnr)]
end

local function clear_marks(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
end

local function render_preview(state)
  local bufnr = state.bufnr
  clear_marks(bufnr)

  for line = state.start_idx, state.end_idx - 1 do
    pcall(vim.api.nvim_buf_add_highlight, bufnr, ns, "DiffDelete", line, 0, -1)
  end

  local virt_lines = {
    { { "┄ AI edit preview", "Comment" } },
  }
  for _, line in ipairs(state.proposed_lines) do
    table.insert(virt_lines, { { "+ " .. line, "DiffAdd" } })
  end

  local row = state.end_idx > 0 and (state.end_idx - 1) or 0
  vim.api.nvim_buf_set_extmark(bufnr, ns, row, 0, {
    virt_lines = virt_lines,
    virt_lines_above = false,
    hl_mode = "combine",
    priority = 200,
  })
end

function M.preview_edit(bufnr, start_line, end_line, proposed_text)
  bufnr = current_buf(bufnr)
  start_line = tonumber(start_line)
  end_line = tonumber(end_line)

  assert(start_line and end_line, "start_line and end_line must be numbers")
  assert(start_line >= 1, "start_line must be >= 1")
  assert(end_line >= start_line, "end_line must be >= start_line")

  M.reject_edit(bufnr)

  local start_idx = start_line - 1
  local end_idx = end_line
  local original_lines = vim.api.nvim_buf_get_lines(bufnr, start_idx, end_idx, false)
  local proposed_lines = split_lines(proposed_text)

  local state = {
    bufnr = bufnr,
    start_line = start_line,
    end_line = end_line,
    start_idx = start_idx,
    end_idx = end_idx,
    original_lines = original_lines,
    proposed_lines = proposed_lines,
    proposed_text = decode_text(proposed_text),
  }

  M._state[bufnr] = state
  render_preview(state)

  return {
    active = true,
    bufnr = bufnr,
    start_line = start_line,
    end_line = end_line,
    original_line_count = #original_lines,
    proposed_line_count = #proposed_lines,
  }
end

function M.accept_edit(bufnr)
  bufnr = current_buf(bufnr)
  local state = state_for(bufnr)
  if not state then
    return { active = false, applied = false, reason = "no_preview" }
  end

  vim.api.nvim_buf_set_lines(bufnr, state.start_idx, state.end_idx, false, state.proposed_lines)
  clear_marks(bufnr)
  M._state[bufnr] = nil

  return {
    active = false,
    applied = true,
    bufnr = bufnr,
    start_line = state.start_line,
    end_line = state.end_line,
    applied_line_count = #state.proposed_lines,
  }
end

function M.reject_edit(bufnr)
  bufnr = current_buf(bufnr)
  local state = state_for(bufnr)
  if not state then
    return { active = false, rejected = false, reason = "no_preview" }
  end

  clear_marks(bufnr)
  M._state[bufnr] = nil

  return {
    active = false,
    rejected = true,
    bufnr = bufnr,
    start_line = state.start_line,
    end_line = state.end_line,
  }
end

function M.preview_status(bufnr)
  local state = state_for(bufnr)
  if not state then
    return { active = false }
  end

  return {
    active = true,
    bufnr = state.bufnr,
    start_line = state.start_line,
    end_line = state.end_line,
    original_line_count = #state.original_lines,
    proposed_line_count = #state.proposed_lines,
  }
end

local function prompt_preview(start_line, end_line)
  vim.ui.input({
    prompt = "AI replacement (use \\n for newline): ",
  }, function(input)
    if not input or input == "" then
      return
    end
    local ok, err = pcall(M.preview_edit, 0, start_line, end_line, input)
    if not ok then
      vim.notify(err, vim.log.levels.ERROR)
    end
  end)
end

function M.prompt_current_line_preview()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  prompt_preview(line, line)
end

function M.prompt_visual_preview()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  prompt_preview(start_line, end_line)
end

local function create_commands()
  vim.api.nvim_create_user_command("AIEditPreview", function(cmd)
    local args = cmd.fargs
    local start_line
    local end_line
    local text

    if cmd.range > 0 and #args >= 1 and tonumber(args[1]) == nil then
      start_line = cmd.line1
      end_line = cmd.line2
      text = table.concat(args, " ")
    elseif #args >= 3 then
      start_line = tonumber(args[1])
      end_line = tonumber(args[2])
      text = table.concat(vim.list_slice(args, 3), " ")
    else
      error("Usage: :AIEditPreview {start} {end} {text} or visually select lines and run :AIEditPreview {text}")
    end

    M.preview_edit(0, start_line, end_line, text)
  end, {
    nargs = "+",
    range = true,
    desc = "Preview an AI edit inline",
  })

  vim.api.nvim_create_user_command("AIEditAccept", function()
    M.accept_edit(0)
  end, { nargs = 0, desc = "Accept current AI edit preview" })

  vim.api.nvim_create_user_command("AIEditReject", function()
    M.reject_edit(0)
  end, { nargs = 0, desc = "Reject current AI edit preview" })
end

local function create_keymaps()
  vim.keymap.set("n", "<leader>ap", function()
    M.prompt_current_line_preview()
  end, { desc = "AI Preview Edit" })

  vim.keymap.set("x", "<leader>ap", function()
    M.prompt_visual_preview()
  end, { desc = "AI Preview Edit" })

  vim.keymap.set("n", "<leader>aa", function()
    M.accept_edit(0)
  end, { desc = "AI Accept Edit" })

  vim.keymap.set("n", "<leader>ar", function()
    M.reject_edit(0)
  end, { desc = "AI Reject Edit" })
end

local function mcp_success(data)
  return {
    content = { { type = "text", text = vim.json.encode(data) } },
    isError = false,
  }
end

function M.mcp_tools()
  return {
    ai_preview_edit = {
      description = "Preview an AI-proposed edit inline in Neovim without applying it yet.",
      parameters = {
        type = "object",
        properties = {
          bufnr = { type = "number", description = "Target buffer number. Use 0 for current buffer." },
          start_line = { type = "number", description = "1-indexed starting line, inclusive." },
          end_line = { type = "number", description = "1-indexed ending line, inclusive." },
          proposed_text = { type = "string", description = "Replacement text. Use \\n for newlines if needed." },
        },
        required = { "start_line", "end_line", "proposed_text" },
      },
      handler = function(params)
        return mcp_success(M.preview_edit(params.bufnr or 0, params.start_line, params.end_line, params.proposed_text))
      end,
    },
    ai_accept_edit = {
      description = "Accept the current inline AI edit preview and apply it to the buffer.",
      parameters = {
        type = "object",
        properties = {
          bufnr = { type = "number", description = "Target buffer number. Use 0 for current buffer." },
        },
      },
      handler = function(params)
        return mcp_success(M.accept_edit((params or {}).bufnr or 0))
      end,
    },
    ai_reject_edit = {
      description = "Reject the current inline AI edit preview and clear the preview.",
      parameters = {
        type = "object",
        properties = {
          bufnr = { type = "number", description = "Target buffer number. Use 0 for current buffer." },
        },
      },
      handler = function(params)
        return mcp_success(M.reject_edit((params or {}).bufnr or 0))
      end,
    },
    ai_edit_status = {
      description = "Inspect the current inline AI edit preview status for a buffer.",
      parameters = {
        type = "object",
        properties = {
          bufnr = { type = "number", description = "Target buffer number. Use 0 for current buffer." },
        },
      },
      handler = function(params)
        return mcp_success(M.preview_status((params or {}).bufnr or 0))
      end,
    },
  }
end

function M.setup()
  if M._setup_done then
    return
  end
  M._setup_done = true
  create_commands()
  create_keymaps()
end

return M
