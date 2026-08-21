local M = {}

local ns = vim.api.nvim_create_namespace("jcode_ai_preview")
local ui_ns = vim.api.nvim_create_namespace("jcode_ai_inline_ui")

M._setup_done = false
M._state = {}

local current_context

local function state_dir()
  return vim.fn.stdpath("state") .. "/jcode_ai"
end

local function client_state_path()
  return state_dir() .. "/client.json"
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
  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then
    return nil
  end
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

local function load_client_state()
  local state = read_json_file(client_state_path())
  if type(state) ~= "table" then
    return { session_id = "", model = "" }
  end
  state.session_id = tostring(state.session_id or "")
  state.model = tostring(state.model or "")
  return state
end

local function save_client_state(state)
  ensure_dir(state_dir())
  write_json_file(client_state_path(), {
    session_id = tostring(state.session_id or ""),
    model = tostring(state.model or ""),
  })
end

local function emit_user_event(pattern, data)
  pcall(vim.api.nvim_exec_autocmds, "User", {
    pattern = pattern,
    data = data,
    modeline = false,
  })
end

local function parse_panel_output(output)
  local session_id = nil
  local chunks = {}
  local final_text = nil
  for line in tostring(output or ""):gmatch("[^\r\n]+") do
    local ok, event = pcall(vim.json.decode, line)
    if ok and type(event) == "table" then
      local line_session = event.session_id or event.sessionId
      if type(line_session) == "string" and line_session ~= "" then
        session_id = line_session
      end
      local kind = tostring(event.type or event.kind or ""):lower()
      local text = event.delta or event.text or event.content or event.message
      if type(text) == "string" and text ~= "" then
        if kind == "done" or kind == "assistant_final" then
          final_text = text
        elseif kind ~= "status" and kind ~= "progress" and kind ~= "tool" and kind ~= "session" then
          table.insert(chunks, text)
        end
      end
    end
  end
  local text = final_text or table.concat(chunks, "")
  if text == "" then
    text = tostring(output or "")
  end
  return {
    session_id = session_id,
    text = vim.trim(text),
  }
end

local function looks_like_resume_session_error(text)
  local lower = string.lower(tostring(text or ""))
  return lower:find("session", 1, true) ~= nil and (
    lower:find("not found", 1, true) ~= nil
    or lower:find("found match", 1, true) ~= nil
    or lower:find("multiple", 1, true) ~= nil
    or lower:find("ambiguous", 1, true) ~= nil
    or lower:find("no session", 1, true) ~= nil
  )
end

local function run_jcode_command(cmd)
  local result = vim.system(cmd, { text = true }):wait()
  local parsed = parse_panel_output(result.stdout)
  return result, parsed
end

local function close_window(win)
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

local function cursor_anchor()
  local cursor = vim.api.nvim_win_get_cursor(0)
  return {
    row = cursor[1],
    col = cursor[2],
  }
end

local function open_cursor_float(buf, opts)
  opts = opts or {}
  local anchor = cursor_anchor()
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "win",
    win = vim.api.nvim_get_current_win(),
    row = math.max(anchor.row, 1),
    col = anchor.col,
    width = opts.width,
    height = opts.height,
    border = opts.border or "rounded",
    style = "minimal",
    title = opts.title,
    title_pos = opts.title_pos or "left",
    noautocmd = true,
    zindex = opts.zindex or 180,
  })
  if opts.winhl then
    vim.wo[win].winhl = opts.winhl
  end
  if opts.cursorline then
    vim.wo[win].cursorline = true
  end
  return win
end

local function set_close_keys(buf, win, extra)
  local function close()
    close_window(win)
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })
  if extra then
    extra(close)
  end
end

local function open_inline_input(title, placeholder, on_submit)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false

  local display = placeholder ~= "" and placeholder or "Type prompt and press Enter"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "> " })
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_text = { { display, "Comment" } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
    virt_text_win_col = 2,
  })

  local width = math.min(math.max(36, #title + 12), math.max(vim.o.columns - 8, 20))
  local win = open_cursor_float(buf, {
    width = width,
    height = 1,
    title = title,
    winhl = "NormalFloat:Pmenu,FloatBorder:FloatBorder",
  })

  local function finish()
    clear_inline_hint(0)
    close_window(win)
  end

  local function submit()
    local input = table.concat(vim.api.nvim_buf_get_lines(buf, 0, 1, false), "")
    input = vim.trim((input:gsub("^>%s*", "")))
    finish()
    if input ~= "" then
      on_submit(input)
    end
  end

  set_close_keys(buf, win, function()
    local cancel = function()
      finish()
    end
    vim.keymap.set("i", "<Esc>", cancel, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("i", "<CR>", submit, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("i", "<Tab>", submit, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<CR>", submit, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Tab>", submit, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "q", cancel, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Esc>", cancel, { buffer = buf, nowait = true, silent = true })
  end)

  vim.api.nvim_win_set_cursor(win, { 1, 2 })
  vim.cmd("startinsert")
  return { buf = buf, win = win, submit = submit, close = finish }
end

local function open_inline_dropdown(title, items, on_pick)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true

  local lines = {}
  local max_width = #title
  for i, item in ipairs(items) do
    local label = string.format("  %s", item.label)
    max_width = math.max(max_width, #label)
    table.insert(lines, label)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  local win = open_cursor_float(buf, {
    width = math.min(max_width + 2, math.max(vim.o.columns - 8, 20)),
    height = #lines,
    title = title,
    cursorline = true,
    winhl = "NormalFloat:Pmenu,FloatBorder:FloatBorder,CursorLine:PmenuSel",
  })

  local function finish()
    clear_inline_hint(0)
    close_window(win)
  end

  local function pick(index)
    local item = items[index]
    finish()
    if item then
      on_pick(item)
    end
  end

  set_close_keys(buf, win, function()
    vim.keymap.set("n", "<CR>", function()
      pick(vim.api.nvim_win_get_cursor(win)[1])
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Tab>", function()
      pick(vim.api.nvim_win_get_cursor(win)[1])
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<S-Tab>", function()
      local line = vim.api.nvim_win_get_cursor(win)[1]
      local prev_line = line <= 1 and #items or (line - 1)
      vim.api.nvim_win_set_cursor(win, { prev_line, 0 })
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Down>", function()
      local line = vim.api.nvim_win_get_cursor(win)[1]
      local next_line = line >= #items and #items or (line + 1)
      vim.api.nvim_win_set_cursor(win, { next_line, 0 })
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Up>", function()
      local line = vim.api.nvim_win_get_cursor(win)[1]
      local prev_line = line <= 1 and 1 or (line - 1)
      vim.api.nvim_win_set_cursor(win, { prev_line, 0 })
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<Right>", function()
      pick(vim.api.nvim_win_get_cursor(win)[1])
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<C-n>", function()
      local line = vim.api.nvim_win_get_cursor(win)[1]
      local next_line = line >= #items and #items or (line + 1)
      vim.api.nvim_win_set_cursor(win, { next_line, 0 })
    end, { buffer = buf, nowait = true, silent = true })
    vim.keymap.set("n", "<C-p>", function()
      local line = vim.api.nvim_win_get_cursor(win)[1]
      local prev_line = line <= 1 and 1 or (line - 1)
      vim.api.nvim_win_set_cursor(win, { prev_line, 0 })
    end, { buffer = buf, nowait = true, silent = true })
    for i = 1, math.min(#items, 9) do
      vim.keymap.set("n", tostring(i), function()
        pick(i)
      end, { buffer = buf, nowait = true, silent = true })
    end
    vim.keymap.set("n", "j", "j", { buffer = buf, nowait = true, silent = true, remap = true })
    vim.keymap.set("n", "k", "k", { buffer = buf, nowait = true, silent = true, remap = true })
  end)

  vim.api.nvim_win_set_cursor(win, { 1, 0 })
  return { buf = buf, win = win, pick = pick, close = finish }
end

local function preset_items(mode)
  if mode == "edit" then
    return {
      { label = "Custom prompt…", prompt = nil },
      { label = "Fix the code", prompt = "Fix the code on this line or selection." },
      { label = "Refactor it", prompt = "Refactor this code to be cleaner and easier to maintain." },
      { label = "Improve naming", prompt = "Improve names and readability without changing behavior." },
      { label = "Add comments", prompt = "Add concise helpful comments only where they add clarity." },
      { label = "Make it concise", prompt = "Make this code more concise while keeping the same behavior." },
    }
  end

  return {
    { label = "Custom prompt…", prompt = nil },
    { label = "Explain this", prompt = "Explain what this line or selection is doing." },
    { label = "Find bugs", prompt = "Look for likely bugs or edge cases in this line or selection." },
    { label = "Suggest improvements", prompt = "Suggest practical improvements for this line or selection." },
    { label = "Summarize", prompt = "Summarize this line or selection briefly." },
    { label = "Add tests ideas", prompt = "Suggest useful test cases for this line or selection." },
  }
end

local function build_context_prompt(prompt, opts)
  opts = opts or {}
  local ctx = current_context(opts.bufnr or 0, opts.start_line, opts.end_line)
  local parts = {
    "Context: nvim",
    string.format("cwd: %s", ctx.cwd),
    string.format("file: %s", ctx.file ~= "" and ctx.file or "[No Name]"),
    string.format("cursor: %d:%d", ctx.cursor.line, ctx.cursor.col + 1),
  }
  if ctx.start_line and ctx.end_line then
    table.insert(parts, string.format("range: %d-%d", ctx.start_line, ctx.end_line))
  end
  if ctx.selection and ctx.selection ~= "" then
    table.insert(parts, "selection:\n```\n" .. ctx.selection .. "\n```")
  end
  if opts.mode == "edit" then
    table.insert(parts, table.concat({
      "Task: return valid JSON only for an edit proposal.",
      "Use exactly this schema:",
      '{"kind":"edit_batch","summary":"short summary","edits":[{"file":"absolute path or empty","start_line":1,"end_line":1,"replacement":"text"}]}',
      "Rules:",
      "- No markdown fences.",
      "- No explanation outside JSON.",
      "- Return exactly one edit for the selected range in the current file.",
      "- replacement must contain the full replacement text for the selected range.",
    }, "\n"))
  else
    table.insert(parts, "Task: answer the user briefly and helpfully using the current Neovim context.")
  end
  table.insert(parts, "User prompt:\n" .. prompt)
  return table.concat(parts, "\n\n")
end

local function strip_code_fences(text)
  local trimmed = vim.trim(text or "")
  local fenced = trimmed:match("^```[%w_-]*\n([%s%S]*)\n```$")
  return fenced and vim.trim(fenced) or trimmed
end

local function normalize_edit_entry(edit, opts)
  opts = opts or {}
  if type(edit) ~= "table" then
    return nil, "invalid_edit_entry"
  end
  local file = tostring(edit.file or edit.path or "")
  local start_line = tonumber(edit.start_line or edit.line_start or edit.start)
  local end_line = tonumber(edit.end_line or edit.line_end or edit["end"])
  local replacement = edit.replacement or edit.proposed_text or edit.text
  if type(replacement) ~= "string" or replacement == "" then
    return nil, "missing_replacement"
  end
  if not start_line or not end_line then
    return nil, "missing_range"
  end
  local current_file = current_context((opts.bufnr or 0), opts.start_line, opts.end_line).file
  if file ~= "" and current_file ~= "" and vim.fs.normalize(file) ~= vim.fs.normalize(current_file) then
    return nil, "edit_targets_other_file"
  end
  return {
    file = file,
    start_line = start_line,
    end_line = end_line,
    replacement = replacement,
  }
end

function M.parse_edit_response(text, opts)
  local body = strip_code_fences(text)
  local ok, decoded = pcall(vim.json.decode, body)
  if not ok or type(decoded) ~= "table" then
    return nil, "invalid_json"
  end

  if decoded.kind == "edit_batch" and type(decoded.edits) == "table" and #decoded.edits > 0 then
    return normalize_edit_entry(decoded.edits[1], opts)
  end

  if decoded.kind == "edit_proposal" and type(decoded.edits) == "table" and #decoded.edits > 0 then
    return normalize_edit_entry(decoded.edits[1], opts)
  end

  if decoded.replacement or decoded.proposed_text then
    return normalize_edit_entry(decoded, opts)
  end

  return nil, "unsupported_edit_schema"
end

function M.preview_edit_response(text, opts)
  local edit, err = M.parse_edit_response(text, opts)
  if not edit then
    return nil, err
  end
  M.preview_edit((opts or {}).bufnr or 0, edit.start_line, edit.end_line, edit.replacement)
  return edit
end

function M.send_prompt_sync(prompt, opts)
  opts = opts or {}
  local client = load_client_state()
  local full_prompt = build_context_prompt(prompt, opts)
  local function build_cmd(session_id)
    local cmd = { "jcode" }
    if client.model ~= "" then
      table.insert(cmd, "-m")
      table.insert(cmd, client.model)
    end
    table.insert(cmd, "run")
    table.insert(cmd, "--ndjson")
    if session_id ~= "" then
      table.insert(cmd, "--resume")
      table.insert(cmd, session_id)
    end
    table.insert(cmd, full_prompt)
    return cmd
  end

  local used_resume = client.session_id ~= ""
  local result, parsed = run_jcode_command(build_cmd(client.session_id))
  if used_resume and result.code ~= 0 then
    local error_text = table.concat({ result.stderr or "", parsed.text or "" }, "\n")
    if looks_like_resume_session_error(error_text) then
      client.session_id = ""
      save_client_state(client)
      result, parsed = run_jcode_command(build_cmd(""))
    end
  end

  if parsed.session_id and parsed.session_id ~= "" then
    client.session_id = parsed.session_id
    save_client_state(client)
  end
  return {
    code = result.code,
    signal = result.signal,
    session_id = client.session_id ~= "" and client.session_id or parsed.session_id,
    text = parsed.text,
    stderr = result.stderr,
    ok = result.code == 0,
  }
end

local function show_response_window(title, text)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = vim.split(text == "" and "[empty response]" or text, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown"
  local width = math.min(math.max(60, math.floor(vim.o.columns * 0.6)), vim.o.columns - 4)
  local height = math.min(math.max(8, #lines + 2), vim.o.lines - 4)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = "rounded",
    style = "minimal",
    title = title,
    title_pos = "center",
  })
  vim.keymap.set("n", "q", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, { buffer = buf, nowait = true, silent = true })
end

function M.ask_agent_edit(prompt, opts)
  local result = M.send_prompt_sync(prompt, vim.tbl_extend("force", opts or {}, { mode = "edit" }))
  if not result.ok then
    return result, result.stderr ~= "" and result.stderr or result.text
  end
  if result.text == "" then
    return result, "empty_response"
  end
  local _, err = M.preview_edit_response(result.text, opts)
  if err then
    return result, err
  end
  return result
end

function M.ask_agent(prompt, opts)
  local result = M.send_prompt_sync(prompt, vim.tbl_extend("force", opts or {}, { mode = "ask" }))
  if result.ok then
    show_response_window("Jcode Quick Ask", result.text)
  else
    show_response_window("Jcode Quick Ask Error", result.stderr ~= "" and result.stderr or result.text)
  end
  return result
end

local function current_buf(bufnr)
  if bufnr == nil or bufnr == 0 then
    return vim.api.nvim_get_current_buf()
  end
  return bufnr
end

local function clear_inline_hint(bufnr)
  pcall(vim.api.nvim_buf_clear_namespace, current_buf(bufnr), ui_ns, 0, -1)
end

local function show_inline_hint(bufnr, line, chunks)
  bufnr = current_buf(bufnr)
  clear_inline_hint(bufnr)
  vim.api.nvim_buf_set_extmark(bufnr, ui_ns, math.max((line or 1) - 1, 0), 0, {
    virt_text = chunks,
    virt_text_pos = "eol",
    hl_mode = "combine",
    priority = 120,
  })
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

current_context = function(bufnr, start_line, end_line)
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

local function run_prompt_action(mode, input, start_line, end_line)
  if mode == "edit" then
    local result, err = M.ask_agent_edit(input, {
      bufnr = 0,
      start_line = start_line,
      end_line = end_line,
    })
    if err then
      vim.notify("AI edit failed: " .. err, vim.log.levels.ERROR)
    elseif result and result.session_id then
      vim.notify("AI preview ready from session " .. result.session_id, vim.log.levels.INFO)
    end
    return
  end

  M.ask_agent(input, {
    bufnr = 0,
    start_line = start_line,
    end_line = end_line,
  })
end

local function open_prompt_picker(mode, start_line, end_line)
  local items = preset_items(mode)
  local prompt_chunks = {
    { " AI ", "Special" },
    { items[2] and items[2].label or "Prompt", "Comment" },
    { "  ·  Tab accept  ·  1-9 choose", "Comment" },
  }
  show_inline_hint(0, start_line, prompt_chunks)
  return open_inline_dropdown(mode == "edit" and "AI Edit" or "Quick Ask", items, function(item)
    if item.prompt then
      run_prompt_action(mode, item.prompt, start_line, end_line)
      return
    end

    show_inline_hint(0, start_line, {
      { " AI prompt > ", "Special" },
      { mode == "edit" and "describe the change" or "ask about this code", "Comment" },
      { "  ·  Tab submit", "Comment" },
    })

    open_inline_input(
      mode == "edit" and "Ask AI edit" or "Quick ask Jcode",
      mode == "edit" and "Describe the change you want" or "Ask about this line or selection",
      function(input)
        run_prompt_action(mode, input, start_line, end_line)
      end
    )
  end)
end

local function prompt_agent_edit(start_line, end_line)
  open_prompt_picker("edit", start_line, end_line)
end

function M.prompt_current_line_agent_edit()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  prompt_agent_edit(line, line)
end

function M.prompt_visual_agent_edit()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  prompt_agent_edit(start_line, end_line)
end

local function prompt_agent_ask(start_line, end_line)
  open_prompt_picker("ask", start_line, end_line)
end

function M.prompt_current_line_agent_ask()
  local line = vim.api.nvim_win_get_cursor(0)[1]
  prompt_agent_ask(line, line)
end

function M.prompt_visual_agent_ask()
  local start_line = vim.fn.line("v")
  local end_line = vim.fn.line(".")
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  prompt_agent_ask(start_line, end_line)
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

  vim.api.nvim_create_user_command("AIQuickAsk", function(cmd)
    local prompt = table.concat(cmd.fargs, " ")
    if prompt == "" then
      error("Usage: :AIQuickAsk {prompt}")
    end
    M.ask_agent(prompt, {
      bufnr = 0,
      start_line = cmd.range > 0 and cmd.line1 or nil,
      end_line = cmd.range > 0 and cmd.line2 or nil,
    })
  end, { nargs = "+", range = true, desc = "Send a quick ask directly to Jcode with current Neovim context" })
end

local function create_keymaps()
  vim.keymap.set("n", "<leader>ap", function()
    M.prompt_current_line_agent_edit()
  end, { desc = "AI Prompt Edit" })

  vim.keymap.set("x", "<leader>ap", function()
    M.prompt_visual_agent_edit()
  end, { desc = "AI Prompt Edit" })

  vim.keymap.set("n", "<leader>aa", function()
    M.accept_edit(0)
  end, { desc = "AI Accept Edit" })

  vim.keymap.set("n", "<leader>ar", function()
    M.reject_edit(0)
  end, { desc = "AI Reject Edit" })

  vim.keymap.set("n", "<leader>aq", function()
    M.prompt_current_line_agent_ask()
  end, { desc = "AI Quick Ask" })

  vim.keymap.set("x", "<leader>aq", function()
    M.prompt_visual_agent_ask()
  end, { desc = "AI Quick Ask" })
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

M._test = {
  preset_items = preset_items,
  open_inline_dropdown = open_inline_dropdown,
  open_inline_input = open_inline_input,
  open_prompt_picker = open_prompt_picker,
  run_prompt_action = run_prompt_action,
  show_inline_hint = show_inline_hint,
  clear_inline_hint = clear_inline_hint,
  ui_ns = ui_ns,
}

return M
