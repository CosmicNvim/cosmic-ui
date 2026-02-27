local utils = require('cosmic-ui.utils')
local window = require('cosmic-ui.window')
local transform = require('cosmic-ui.codeactions.transform')
local lifecycle = require('cosmic-ui.codeactions.ui.lifecycle')
local model = require('cosmic-ui.codeactions.ui.model')
local render = require('cosmic-ui.codeactions.ui.render')
local input = require('cosmic-ui.codeactions.ui.input')
local logger = utils.Logger

local M = {}

local function compute_content_width(rows, min_width)
  local width = math.max(min_width or 30, 30)
  for _, row in ipairs(rows) do
    width = math.max(width, vim.fn.strdisplaywidth(row.text))
  end
  return width
end

local function compute_height(row_count)
  local max_height = math.max(8, math.floor((vim.o.lines - vim.o.cmdheight) * 0.7))
  return math.max(1, math.min(row_count, max_height))
end

local function submit_action(action)
  local client = action.client
  local command = action.command

  if not client then
    logger:warn('Code action client is no longer available')
    return
  end

  if not command.edit and transform.supports_code_action_resolve(client) then
    client:request('codeAction/resolve', command, function(resolved_err, resolved_action)
      if resolved_err then
        local code = resolved_err.code or 'unknown'
        local msg = resolved_err.message or vim.inspect(resolved_err)
        logger:error(code .. ': ' .. msg)
        return
      end

      if resolved_action then
        transform.execute_action(transform.transform_action(resolved_action), client)
      else
        transform.execute_action(transform.transform_action(command), client)
      end
    end)
    return
  end

  transform.execute_action(transform.transform_action(command), client)
end

M.open = function(results_lsp, user_opts)
  if not results_lsp or next(results_lsp) == nil then
    logger:warn('No results from textDocument/codeAction')
    return
  end

  lifecycle.close_current()

  local built = model.build(results_lsp)
  if #built.actions == 0 then
    logger:log('No code actions available')
    return
  end

  local border = user_opts.border or {}
  local border_style = border.style or vim.o.winborder
  if border_style == '' then
    border_style = nil
  end
  local content_width = compute_content_width(built.rows, user_opts.min_width or built.min_width)
  local width = content_width + 2
  local height = compute_height(#built.rows)

  local buf = window.create_scratch_buf({
    filetype = 'cosmicui-codeactions',
    modifiable = false,
    bufhidden = 'wipe',
  })
  if not buf then
    return
  end

  local win = window.open_float(buf, {
    relative = 'cursor',
    row = 1,
    col = 0,
    width = width,
    height = height,
    border = border_style,
    title = border.title,
    title_pos = border.title_align,
    footer = '(1/' .. tostring(#built.actions) .. ')',
    footer_pos = 'right',
  })
  if not win then
    window.safe_delete_buf(buf, { force = true })
    return
  end

  vim.wo[win].cursorline = true
  vim.wo[win].cursorlineopt = 'line'
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
  if border.bottom_hl then
    table.insert(winhl, 'FloatFooter:' .. border.bottom_hl)
  end
  if #winhl > 0 then
    vim.wo[win].winhl = table.concat(winhl, ',')
  end

  local ui = {
    buf = buf,
    win = win,
    row = 1,
    col = 0,
    model = built,
    selected = 1,
    user_opts = user_opts,
    border = border,
    ns = vim.api.nvim_create_namespace('cosmic-ui-codeactions'),
    content_width = content_width,
  }

  lifecycle.attach_close_autocmds(ui, lifecycle.close_current)
  lifecycle.set_ui(ui)

  local handlers = {
    submit_action = submit_action,
  }

  local deps = {
    close_fn = lifecycle.close_current,
    render_fn = render.render,
  }

  input.set_keymaps(ui, handlers, deps)
  render.render(ui)

  vim.api.nvim_buf_call(buf, function()
    if vim.fn.mode() ~= 'n' then
      vim.api.nvim_input('<Esc>')
    end
  end)
end

M.close = lifecycle.close_current

return M
