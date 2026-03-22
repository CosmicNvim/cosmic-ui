local lsp = vim.lsp
local utils = require('cosmic-ui.utils')
local config = require('cosmic-ui.config')
local window = require('cosmic-ui.window')
local panel = require('cosmic-ui.ui.panel')
local model = require('cosmic-ui.rename.model')

local M = {}
local prompt_ns = vim.api.nvim_create_namespace('cosmic-ui-rename-prompt')
local panel_ns = vim.api.nvim_create_namespace('cosmic-ui-rename-panel')

local validation_copy = {
  empty = 'Name cannot be empty',
  unchanged = 'Name is unchanged',
}

local function assert_table(val)
  return val == nil or type(val) == 'table'
end

local function validate_open_opts(opts)
  if not assert_table(opts) then
    error('rename.open: invalid arguments')
  end

  if not opts then
    return
  end

  local allowed = {
    prompt = true,
    default_value = true,
    on_submit = true,
    window = true,
  }

  for key in pairs(opts) do
    if not allowed[key] then
      error('rename.open: invalid arguments')
    end
  end

  if opts.prompt ~= nil and type(opts.prompt) ~= 'string' then
    error('rename.open: invalid arguments')
  end

  if opts.default_value ~= nil and type(opts.default_value) ~= 'string' then
    error('rename.open: invalid arguments')
  end

  if opts.on_submit ~= nil and type(opts.on_submit) ~= 'function' then
    error('rename.open: invalid arguments')
  end

  if not assert_table(opts.window) then
    error('rename.open: invalid arguments')
  end
end

local function default_submitter(curr_name, target_ctx)
  return function(new_name)
    if not (target_ctx.winid and vim.api.nvim_win_is_valid(target_ctx.winid)) then
      return
    end

    pcall(vim.api.nvim_win_call, target_ctx.winid, function()
      pcall(vim.api.nvim_win_set_cursor, target_ctx.winid, target_ctx.cursor)
      lsp.buf.rename(new_name, { bufnr = target_ctx.bufnr })
    end)
  end
end

local function footer_line(entries)
  local text = ''
  local spans = {}
  local col = 0

  for idx, entry in ipairs(entries or {}) do
    if idx > 1 then
      text = text .. '  '
      col = col + 2
    end

    local key = entry.key or ''
    local hint = entry.text or ''

    text = text .. key
    table.insert(spans, {
      highlight = entry.key_highlight,
      start_col = col,
      end_col = col + #key,
    })
    col = col + #key

    if hint ~= '' then
      text = text .. ':' .. hint
      table.insert(spans, {
        highlight = entry.text_highlight,
        start_col = col + 1,
        end_col = col + 1 + #hint,
      })
      col = col + 1 + #hint
    end
  end

  return text, spans
end

local function build_validation_row(reason)
  local text = validation_copy[reason]
  if not text then
    return nil
  end

  return {
    kind = 'state',
    state = (reason == 'unchanged') and 'warn' or 'error',
    text = text,
  }
end

local function build_panel_model(curr_name, reason)
  local rows = {
    { kind = 'context', text = ('Current: %s'):format(curr_name) },
  }

  local validation_row = build_validation_row(reason)
  if validation_row then
    table.insert(rows, validation_row)
  end

  return panel.prepare({
    layout = 'compact',
    rows = rows,
    footer = {
      { key = 'Enter', text = 'rename' },
      { key = 'Esc', text = 'cancel' },
    },
  })
end

local function render(ui, value)
  if not (ui.buf and vim.api.nvim_buf_is_valid(ui.buf)) then
    return
  end

  ui.value = value
  ui.panel = build_panel_model(ui.curr_name, ui.validation_reason)

  local lines = {}
  local highlights = {}
  local compact_layout = ui.panel and ui.panel.layout == 'compact'

  local function push_line(text, meta)
    table.insert(lines, text)
    if meta then
      highlights[#lines] = meta
    end
  end

  local prompt_line = ui.prompt .. value

  if compact_layout then
    push_line(prompt_line)
  else
    for _, row in ipairs(ui.panel.rows or {}) do
      local highlight = row.highlight
      if row.kind == 'context' then
        highlight = 'CosmicUiPanelSection'
      end

      push_line(' ' .. (row.text or '') .. ' ', { highlight = highlight })
    end

    push_line('')
    push_line(prompt_line)
  end

  local prompt_row = #lines

  if not compact_layout and ui.panel.footer and #ui.panel.footer > 0 then
    push_line('')
    local footer_text, spans = footer_line(ui.panel.footer)
    for _, span in ipairs(spans) do
      span.start_col = span.start_col + 1
      span.end_col = span.end_col + 1
    end
    push_line(' ' .. footer_text .. ' ', { spans = spans })
  end

  local width = ui.fixed_width or 30
  if not ui.fixed_width then
    for _, line in ipairs(lines) do
      width = math.max(width, vim.fn.strdisplaywidth(line))
    end
  end

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    local cfg = vim.api.nvim_win_get_config(ui.win)
    cfg.width = width
    cfg.height = ui.fixed_height or #lines
    vim.api.nvim_win_set_config(ui.win, cfg)
  end

  local was_modifiable = vim.bo[ui.buf].modifiable
  vim.bo[ui.buf].modifiable = true
  vim.api.nvim_buf_set_lines(ui.buf, 0, -1, false, lines)
  vim.bo[ui.buf].modifiable = was_modifiable

  vim.api.nvim_buf_clear_namespace(ui.buf, panel_ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(ui.buf, prompt_ns, 0, -1)

  for line_no, meta in pairs(highlights) do
    if meta.highlight then
      vim.api.nvim_buf_add_highlight(ui.buf, panel_ns, meta.highlight, line_no - 1, 0, -1)
    end

    for _, span in ipairs(meta.spans or {}) do
      if span.end_col >= span.start_col then
        vim.api.nvim_buf_add_highlight(ui.buf, panel_ns, span.highlight, line_no - 1, span.start_col, span.end_col)
      end
    end
  end

  if #ui.prompt > 0 then
    vim.api.nvim_buf_set_extmark(ui.buf, prompt_ns, prompt_row - 1, 0, {
      end_row = prompt_row - 1,
      end_col = #ui.prompt,
      hl_group = ui.prompt_hl,
      priority = 300,
    })
  end

  ui.prompt_row = prompt_row
  ui.prompt_col = #ui.prompt

  if ui.win and vim.api.nvim_win_is_valid(ui.win) then
    pcall(vim.api.nvim_win_set_cursor, ui.win, { prompt_row, #prompt_line })
  end
end

local function set_cursor_col(ui, col)
  return pcall(vim.api.nvim_win_set_cursor, ui.win, { ui.prompt_row, col })
end

local function ensure_cursor_after_prompt(ui)
  if not (ui.win and vim.api.nvim_win_is_valid(ui.win)) then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(ui.win)
  local prompt_line = vim.api.nvim_buf_get_lines(ui.buf, ui.prompt_row - 1, ui.prompt_row, true)[1] or ''
  local col = cursor[2]

  if cursor[1] ~= ui.prompt_row then
    set_cursor_col(ui, math.max(ui.prompt_col, math.min(col, #prompt_line)))
    return
  end

  if col < ui.prompt_col then
    set_cursor_col(ui, ui.prompt_col)
  elseif col > #prompt_line then
    set_cursor_col(ui, #prompt_line)
  end
end

local function backspace(ui)
  local cursor = vim.api.nvim_win_get_cursor(ui.win)
  local col = cursor[2]
  if cursor[1] ~= ui.prompt_row then
    ensure_cursor_after_prompt(ui)
    return
  end

  if col <= ui.prompt_col then
    return
  end

  vim.api.nvim_buf_set_text(ui.buf, ui.prompt_row - 1, col - 1, ui.prompt_row - 1, col, { '' })
  set_cursor_col(ui, col - 1)
end

local function stop_insert_mode_if_needed()
  local ok, mode = pcall(vim.fn.mode)
  if not ok or type(mode) ~= 'string' then
    return
  end

  local mode_prefix = mode:sub(1, 1)
  if mode_prefix == 'i' or mode_prefix == 'R' then
    pcall(vim.cmd, 'stopinsert')
  end
end

M.open = function(opts)
  validate_open_opts(opts)

  opts = opts or {}
  local target_bufnr = vim.api.nvim_get_current_buf()
  local target_winid = vim.api.nvim_get_current_win()
  local target_cursor = vim.api.nvim_win_get_cursor(target_winid)
  local curr_name = vim.fn.expand('<cword>')

  local clients = vim.lsp.get_clients({ bufnr = 0, method = 'textDocument/rename' })
  if #clients == 0 then
    utils.Logger:warn('No LSP clients with rename attached')
    return
  end

  local user_opts = config.module_opts('rename') or {}
  local user_border = user_opts.border or {}
  local prompt = opts.prompt or user_opts.prompt or '> '
  local default_value = opts.default_value or curr_name
  local on_submit = opts.on_submit
    or default_submitter(curr_name, {
      bufnr = target_bufnr,
      winid = target_winid,
      cursor = target_cursor,
    })

  local merged_window_opts = utils.merge({
    relative = 'cursor',
    row = 1,
    col = 0,
    width = math.max(30, #prompt + #default_value + 2),
    height = 5,
    zindex = 50,
    border = {
      style = user_border.style or vim.o.winborder,
      title = user_border.title,
      title_align = user_border.title_align,
      highlight = user_border.highlight,
      title_hl = user_border.title_hl,
    },
  }, opts.window or {})

  local buf = window.create_scratch_buf({
    filetype = 'cosmicui-rename',
    modifiable = true,
    bufhidden = 'wipe',
  })
  if not buf then
    return
  end

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false

  local border = merged_window_opts.border or {}
  local win = window.open_float(buf, {
    relative = merged_window_opts.relative,
    row = merged_window_opts.row,
    col = merged_window_opts.col,
    width = math.max(1, merged_window_opts.width or 30),
    height = math.max(1, merged_window_opts.height or 5),
    zindex = merged_window_opts.zindex,
    border = border.style,
    title = border.title,
    title_pos = border.title_align,
  })
  if not win then
    window.safe_delete_buf(buf, { force = true })
    return
  end

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].wrap = false

  local winhl = {}
  if border.highlight then
    table.insert(winhl, 'FloatBorder:' .. border.highlight)
  end
  if border.title_hl then
    table.insert(winhl, 'FloatTitle:' .. border.title_hl)
  end
  if #winhl > 0 then
    vim.wo[win].winhl = table.concat(winhl, ',')
  end

  local ui = {
    buf = buf,
    win = win,
    prompt = prompt,
    prompt_hl = user_opts.prompt_hl or 'Comment',
    curr_name = curr_name,
    value = default_value,
    validation_reason = nil,
    origin_win = target_winid,
    origin_cursor = target_cursor,
    fixed_width = opts.window and opts.window.width or nil,
    fixed_height = opts.window and opts.window.height or nil,
    closed = false,
    submitted = false,
  }

  local augroup = vim.api.nvim_create_augroup('cosmic_ui_rename_' .. tostring(buf), { clear = true })
  ui.augroup = augroup

  local function restore_origin_state()
    window.restore_focus(ui.origin_win)
    if ui.origin_win and ui.origin_cursor and vim.api.nvim_win_is_valid(ui.origin_win) then
      pcall(vim.api.nvim_win_set_cursor, ui.origin_win, ui.origin_cursor)
    end
  end

  local function restore_origin_state_deferred()
    vim.schedule(function()
      vim.schedule(restore_origin_state)
    end)
  end

  local function close(opts)
    opts = opts or {}

    if ui.closed then
      return
    end
    ui.closed = true

    stop_insert_mode_if_needed()
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
    window.safe_close_win(win)
    window.safe_delete_buf(buf, { force = true })
    if opts.restore_origin_state then
      restore_origin_state_deferred()
    end
  end

  local function cancel()
    close({
      restore_origin_state = true,
    })
  end

  local function dismiss()
    close()
  end

  local function submit()
    local raw_line = vim.api.nvim_buf_get_lines(buf, ui.prompt_row - 1, ui.prompt_row, true)[1] or ''
    local result = model.normalize_submission(prompt, raw_line, curr_name)

    if not result.ok then
      ui.validation_reason = result.reason
      ui.value = model.extract_value(prompt, raw_line)
      ui.panel = build_panel_model(ui.curr_name, ui.validation_reason)
      return
    end

    if ui.submitted then
      return
    end
    ui.submitted = true
    close()
    vim.schedule(function()
      on_submit(result.value)
    end)
  end

  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    group = augroup,
    buffer = buf,
    callback = dismiss,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup,
    pattern = tostring(win),
    callback = dismiss,
  })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
    group = augroup,
    buffer = buf,
    callback = function()
      ensure_cursor_after_prompt(ui)
    end,
  })

  local map_opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set('i', '<BS>', function()
    backspace(ui)
  end, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<Home>', function()
    set_cursor_col(ui, ui.prompt_col)
  end, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<CR>', submit, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<Esc>', cancel, map_opts)
  vim.keymap.set({ 'i', 'n' }, '<C-c>', cancel, map_opts)

  render(ui, default_value)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { ui.prompt_row, #prompt + #default_value })
  vim.cmd('startinsert!')
end

return M
