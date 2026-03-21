local shared_highlights = require('cosmic-ui.ui.highlights')

local M = {}

local function find_token(line, token, init)
  if not line or not token or token == '' then
    return nil, nil
  end

  local start_idx, end_idx = line:find(token, init or 1, true)
  if not start_idx then
    return nil, nil
  end

  return start_idx - 1, end_idx
end

local function add_hl(bufnr, ns, lnum, group, col_start, col_end)
  if not (group and col_start and col_end) then
    return
  end

  vim.api.nvim_buf_add_highlight(bufnr, ns, group, lnum, col_start, col_end)
end

local function status_hl_group(status)
  if status == 'enabled' then
    return 'CosmicUiFmtEnabled'
  end
  if status == 'disabled' then
    return 'CosmicUiFmtDisabled'
  end
  return 'CosmicUiFmtUnavailable'
end

M.ensure = function(state, highlight_links)
  if not state.ns then
    state.ns = vim.api.nvim_create_namespace('cosmic-ui-formatters')
  end

  shared_highlights.ensure()

  for name, link in pairs(highlight_links) do
    if name ~= 'CosmicUiFmtCursorLine' then
      vim.api.nvim_set_hl(0, name, { link = link, default = true })
    end
  end

  local function group_bg(name)
    local ok, hl = pcall(vim.api.nvim_get_hl, 0, { name = name, link = false })
    if not ok or type(hl) ~= 'table' then
      return nil
    end
    return hl.bg
  end

  local bg = group_bg('CursorLine') or group_bg('Visual') or group_bg('PmenuSel')
  if not bg then
    bg = vim.o.background == 'light' and 0xEAEAEA or 0x2A2A2A
  end

  vim.api.nvim_set_hl(0, 'CosmicUiFmtCursorLine', {
    bg = bg,
    nocombine = true,
  })

  vim.api.nvim_set_hl(0, 'CosmicUiFmtCursor', {
    fg = bg,
    bg = bg,
    nocombine = true,
  })

  return state.ns
end

M.apply = function(bufnr, ns, ui, lines)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  if ui.selected and ui.rows and ui.rows[ui.selected] and lines[ui.rows[ui.selected].lnum] then
    local selected_row = ui.rows[ui.selected]
    add_hl(bufnr, ns, selected_row.lnum - 1, 'CosmicUiFmtCursorLine', 0, -1)
  end

  local header_lnum = ui.header_lnum
  if header_lnum and lines[header_lnum] then
    add_hl(bufnr, ns, header_lnum - 1, 'CosmicUiFmtHeader', 0, -1)
    local icon_start, icon_end = find_token(lines[header_lnum], ui.icons.file, 1)
    add_hl(bufnr, ns, header_lnum - 1, 'CosmicUiFmtIcon', icon_start, icon_end)
  end

  for _, row in ipairs(ui.rows) do
    local line = lines[row.lnum]
    if line then
      local lnum = row.lnum - 1
      if row.kind == 'section' then
        add_hl(bufnr, ns, lnum, 'CosmicUiFmtSection', 0, -1)
        if row.subtitle then
          local subtitle_start, subtitle_end = find_token(line, row.subtitle, 1)
          add_hl(bufnr, ns, lnum, 'CosmicUiFmtSubtitle', subtitle_start, subtitle_end)
        end
      else
        local status_start, status_end = find_token(line, row.status_icon, 1)
        add_hl(bufnr, ns, lnum, status_hl_group(row.status), status_start, status_end)

        local icon_start, icon_end = find_token(line, row.source_icon, (status_end or 0) + 1)
        add_hl(bufnr, ns, lnum, 'CosmicUiFmtIcon', icon_start, icon_end)

        if row.reason then
          local reason_start, reason_end = find_token(line, row.reason, (icon_end or 0) + 1)
          add_hl(bufnr, ns, lnum, 'CosmicUiFmtUnavailable', reason_start, reason_end)
        end
      end
    end
  end

  if ui.footer_lnum and ui.footer_spans and lines[ui.footer_lnum] then
    for _, span in ipairs(ui.footer_spans) do
      add_hl(bufnr, ns, ui.footer_lnum - 1, span.highlight, span.start_col, span.end_col)
    end
  end
end

return M
