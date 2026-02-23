local M = {}

M.get_devicons = function(logger)
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if not ok then
    logger:error('nvim-web-devicons is required for cosmic-ui formatters UI.')
    return nil
  end

  return devicons
end

M.make_icons = function(devicons, bufnr)
  local file_path = vim.api.nvim_buf_get_name(bufnr)
  local file_name = vim.fn.fnamemodify(file_path, ':t')
  if file_name == '' then
    file_name = 'file.txt'
  end

  local filetype = vim.bo[bufnr].filetype
  if filetype == '' then
    filetype = 'text'
  end

  local ext = vim.fn.fnamemodify(file_name, ':e')
  local file_icon
  if type(devicons.get_icon_by_filetype) == 'function' then
    file_icon = devicons.get_icon_by_filetype(filetype, { default = true })
  end
  if not file_icon then
    file_icon = devicons.get_icon(file_name, ext, { default = true })
  end
  local lsp_icon = devicons.get_icon('lsp.lua', 'lua', { default = true })
  local conform_icon = devicons.get_icon('conform.lua', 'lua', { default = true })

  return {
    file = file_icon or '*',
    filetype = filetype,
    lsp = lsp_icon or '*',
    conform = conform_icon or '*',
  }
end

M.build_rows = function(status, icons, status_icons)
  local rows = {}

  local fallback = status.conform.fallback or {}
  local global_mode = fallback.display_global_mode or 'never'
  local specific_mode = fallback.display_specific_mode
  local lsp_header_mode = specific_mode or global_mode
  local lsp_header_ghost = ('  %s'):format(lsp_header_mode)

  table.insert(rows, {
    id = 'section_conform',
    text = 'Conform',
    toggleable = false,
    kind = 'section',
  })

  if not status.conform.available then
    table.insert(rows, {
      id = 'conform_unavailable',
      text = ('%s %s %s'):format(status_icons.unavailable, icons.conform, status.conform.reason or 'unavailable'),
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = status_icons.unavailable,
      source_icon = icons.conform,
    })
  elseif #status.conform.formatters == 0 then
    table.insert(rows, {
      id = 'conform_empty',
      text = ('%s %s no formatters to run'):format(status_icons.unavailable, icons.conform),
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = status_icons.unavailable,
      source_icon = icons.conform,
    })
  else
    for _, formatter in ipairs(status.conform.formatters) do
      local row_status = formatter.enabled and 'enabled' or 'disabled'
      local status_icon = status_icons[row_status]
      table.insert(rows, {
        id = 'conform_' .. formatter.name,
        text = ('%s %s %s'):format(status_icon, icons.conform, formatter.name),
        toggleable = true,
        kind = 'item',
        status = row_status,
        status_icon = status_icon,
        source_icon = icons.conform,
        action = {
          kind = 'item',
          source = 'conform',
          name = formatter.name,
        },
      })
    end
  end

  table.insert(rows, {
    id = 'section_lsp',
    text = 'LSP' .. lsp_header_ghost,
    toggleable = false,
    kind = 'section',
    ghost_text = lsp_header_ghost,
  })

  if #status.lsp_clients == 0 then
    table.insert(rows, {
      id = 'lsp_empty',
      text = ('%s %s no attached clients'):format(status_icons.unavailable, icons.lsp),
      toggleable = false,
      kind = 'info',
      status = 'unavailable',
      status_icon = status_icons.unavailable,
      source_icon = icons.lsp,
    })
  else
    for _, client in ipairs(status.lsp_clients) do
      local row_status = client.available and (client.enabled and 'enabled' or 'disabled') or 'unavailable'
      local status_icon = status_icons[row_status]
      local suffix = ''
      if not client.available and client.reason then
        suffix = (' (%s)'):format(client.reason)
      end
      table.insert(rows, {
        id = 'lsp_' .. client.name,
        text = ('%s %s LSP: %s%s'):format(status_icon, icons.lsp, client.name, suffix),
        toggleable = client.available,
        kind = 'item',
        status = row_status,
        status_icon = status_icon,
        source_icon = icons.lsp,
        reason = client.reason,
        action = {
          kind = 'item',
          source = 'lsp',
          name = client.name,
        },
      })
    end
  end

  return rows
end

return M
