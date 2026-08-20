local M = {}

local ns = vim.api.nvim_create_namespace("jcode_ai_preview")

M._setup_done = false
M._state = {}

local function state_dir()
  return vim.fn.stdpath("state") .. "/jcode_ai"
end

local function requests_dir()
  return state_dir() .. "/requests"
end

local function ensure_dir(path)
  vim.fn.mkdir(path, "p")
end

local function request_path(id)
  return requests_dir() .. "/" .. id .. ".json"
end

local function now_iso()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function new_request_id()
  return string.format("req_%d_%d", vim.uv.hrtime(), math.random(1000, 9999))
end

local function write_json_file(path, data)
  vim.fn.writefile({ vim.json.encode(data) }, path)
end

local function read_json_file(path)
  local lines = vim.fn.readfile(path)
  if not lines or vim.tbl_isempty(lines) then
    return nil
  end
  local ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok then
    return nil
  end
  return decoded
end

local function load_request(id)
  return read_json_file(request_path(id))
end

local function save_request(request)
  ensure_dir(requests_dir())
  write_json_file(request_path(request.id), request)
end

local function list_requests(status)
  ensure_dir(requests_dir())
  local files = vim.fn.glob(requests_dir() .. "/*.json", false, true)
  local requests = {}
  for _, path in ipairs(files) do
    local request = read_json_file(path)
    if request and (status == nil or request.status == status) then
      table.insert(requests, request)
    end
  end
  table.sort(requests, function(a, b)
    return (a.created_at or "") < (b.created_at or "")
  end)
  return requests
end

local function emit_user_event(pattern, data)
  pcall(vim.api.nvim_exec_autocmds, "User", {
    pattern = pattern,
    data = data,
    modeline = false,
  })
end

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
  emit_user_event("JcodeAIPreviewCreated", {
    bufnr = bufnr,
    start_line = start_line,
    end_line = end_line,
  })

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
  emit_user_event("JcodeAIPreviewAccepted", {
    bufnr = bufnr,
    start_line = state.start_line,
    end_line = state.end_line,
  })

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
  emit_user_event("JcodeAIPreviewRejected", {
    bufnr = bufnr,
    start_line = state.start_line,
    end_line = state.end_line,
  })

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

local function current_context(bufnr, start_line, end_line)
  bufnr = current_buf(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local lines = nil
  if start_line and end_line then
    lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  end
  return {
    bufnr = bufnr,
    file = name,
    cwd = vim.fn.getcwd(),
    cursor = { line = cursor[1], col = cursor[2] },
    start_line = start_line,
    end_line = end_line,
    selection = lines and table.concat(lines, "\n") or nil,
  }
end

function M.create_request(prompt, opts)
  opts = opts or {}
  local request = {
    id = new_request_id(),
    type = opts.type or "request",
    status = "pending",
    prompt = prompt,
    created_at = now_iso(),
    updated_at = now_iso(),
    context = current_context(opts.bufnr or 0, opts.start_line, opts.end_line),
    response = nil,
  }
  save_request(request)
  emit_user_event("JcodeAIRequestCreated", { id = request.id, type = request.type })
  return request
end

function M.take_request(id)
  local request = load_request(id)
  if not request then
    return nil
  end
  request.status = "in_progress"
  request.updated_at = now_iso()
  save_request(request)
  emit_user_event("JcodeAIRequestTaken", { id = request.id })
  return request
end

function M.respond_request(id, response)
  local request = load_request(id)
  if not request then
    return nil, "request_not_found"
  end
  request.status = "answered"
  request.updated_at = now_iso()
  request.response = response
  save_request(request)

  if response and response.preview_edit then
    local preview = response.preview_edit
    M.preview_edit(
      preview.bufnr or 0,
      preview.start_line,
      preview.end_line,
      preview.proposed_text
    )
  end

  if response and response.message and response.message ~= "" then
    vim.notify("AI response: " .. response.message, vim.log.levels.INFO)
  end

  emit_user_event("JcodeAIRequestResponded", { id = request.id })

  return request
end

local function prompt_request(start_line, end_line)
  vim.ui.input({
    prompt = "Ask agent: ",
  }, function(input)
    if not input or input == "" then
      return
    end
    local request = M.create_request(input, {
      bufnr = 0,
      start_line = start_line,
      end_line = end_line,
      type = "edit_request",
    })
    vim.notify("Queued AI request " .. request.id, vim.log.levels.INFO)
  end)
end

function M.prompt_current_line_request()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  prompt_request(line, line)
end

function M.prompt_visual_request()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  prompt_request(start_line, end_line)
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

  vim.api.nvim_create_user_command("AIAgentRequest", function(cmd)
    local prompt = table.concat(cmd.fargs, " ")
    if prompt == "" then
      error("Usage: :AIAgentRequest {prompt}")
    end
    local request = M.create_request(prompt, {
      bufnr = 0,
      start_line = cmd.range > 0 and cmd.line1 or nil,
      end_line = cmd.range > 0 and cmd.line2 or nil,
      type = "edit_request",
    })
    print(request.id)
  end, { nargs = "+", range = true, desc = "Queue a request from Neovim to the coding agent" })
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

  vim.keymap.set("n", "<leader>aq", function()
    M.prompt_current_line_request()
  end, { desc = "AI Queue Request" })

  vim.keymap.set("x", "<leader>aq", function()
    M.prompt_visual_request()
  end, { desc = "AI Queue Request" })
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
    ai_list_requests = {
      description = "List queued requests created from Neovim for the coding agent.",
      parameters = {
        type = "object",
        properties = {
          status = { type = "string", description = "Optional status filter such as pending or in_progress." },
        },
      },
      handler = function(params)
        return mcp_success(list_requests(params and params.status or nil))
      end,
    },
    ai_take_request = {
      description = "Claim a queued Neovim request for agent processing.",
      parameters = {
        type = "object",
        properties = {
          id = { type = "string", description = "Request id to claim." },
        },
        required = { "id" },
      },
      handler = function(params)
        local request = M.take_request(params.id)
        if not request then
          return {
            content = { { type = "text", text = "request_not_found" } },
            isError = true,
          }
        end
        return mcp_success(request)
      end,
    },
    ai_respond_request = {
      description = "Send an agent response back into Neovim, optionally with a preview edit.",
      parameters = {
        type = "object",
        properties = {
          id = { type = "string", description = "Request id to answer." },
          message = { type = "string", description = "Human-readable response message." },
          preview_edit = {
            type = "object",
            properties = {
              bufnr = { type = "number" },
              start_line = { type = "number" },
              end_line = { type = "number" },
              proposed_text = { type = "string" },
            },
          },
        },
        required = { "id" },
      },
      handler = function(params)
        local request, err = M.respond_request(params.id, {
          message = params.message,
          preview_edit = params.preview_edit,
        })
        if not request then
          return {
            content = { { type = "text", text = err or "request_not_found" } },
            isError = true,
          }
        end
        return mcp_success(request)
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
