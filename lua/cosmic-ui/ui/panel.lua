local M = {}

function M.build(opts)
  opts = opts or {}

  return {
    title = opts.title,
    subtitle = opts.subtitle,
    footer = opts.footer or {},
    rows = opts.rows or {},
    selected = opts.selected,
  }
end

return M
