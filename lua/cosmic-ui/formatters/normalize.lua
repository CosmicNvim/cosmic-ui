local utils = require('cosmic-ui.utils')
local logger = utils.Logger

local M = {}

M.resolve_scope = function(scope)
  if scope == nil then
    return 'buffer'
  end

  if scope == 'buffer' or scope == 'global' then
    return scope
  end

  logger:warn(('Invalid formatter scope `%s`; expected `buffer` or `global`.'):format(tostring(scope)))
  return nil
end

M.resolve_bufnr = function(bufnr)
  local resolved = bufnr or 0
  if resolved == 0 then
    resolved = vim.api.nvim_get_current_buf()
  end
  return resolved
end

M.normalize_backends = function(backend)
  if backend == nil then
    return { 'lsp', 'conform' }
  end

  if type(backend) == 'string' then
    if backend == 'lsp' or backend == 'conform' then
      return { backend }
    end
    logger:warn(('Invalid formatter backend `%s`; expected `lsp` or `conform`.'):format(backend))
    return nil
  end

  if type(backend) == 'table' then
    local dedup = {}
    local out = {}
    for _, item in ipairs(backend) do
      if item == 'lsp' or item == 'conform' then
        if not dedup[item] then
          dedup[item] = true
          table.insert(out, item)
        end
      else
        logger:warn(('Ignoring invalid formatter backend `%s`.'):format(tostring(item)))
      end
    end

    if #out == 0 then
      logger:warn('No valid formatter backends were provided.')
      return nil
    end

    return out
  end

  logger:warn('Invalid formatter backend input; expected string, table, or nil.')
  return nil
end

M.normalize_source = function(source)
  if source == 'lsp' or source == 'conform' then
    return source
  end

  logger:warn(('Invalid formatter source `%s`; expected `lsp` or `conform`.'):format(tostring(source)))
  return nil
end

M.normalize_name = function(name)
  if type(name) == 'string' and name ~= '' then
    return name
  end

  logger:warn('Formatter item name must be a non-empty string.')
  return nil
end

M.normalize_scope_backends_bufnr = function(opts)
  opts = opts or {}
  local scope = M.resolve_scope(opts.scope)
  if not scope then
    return nil
  end

  local backends = M.normalize_backends(opts.backend)
  if not backends then
    return nil
  end

  local bufnr = M.resolve_bufnr(opts.bufnr)
  return {
    scope = scope,
    backends = backends,
    bufnr = bufnr,
  }
end

M.normalize_item_opts = function(opts)
  opts = opts or {}

  local scope = M.resolve_scope(opts.scope)
  if not scope then
    return nil
  end

  local source = M.normalize_source(opts.source)
  if not source then
    return nil
  end

  local name = M.normalize_name(opts.name)
  if not name then
    return nil
  end

  return {
    scope = scope,
    source = source,
    name = name,
    bufnr = M.resolve_bufnr(opts.bufnr),
  }
end

return M
