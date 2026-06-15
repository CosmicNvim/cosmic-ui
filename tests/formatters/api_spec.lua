local formatter_modules = {
  'cosmic-ui',
  'cosmic-ui.config',
  'cosmic-ui.guard',
  'cosmic-ui.utils',
  'cosmic-ui.formatters',
  'cosmic-ui.formatters.normalize',
  'cosmic-ui.formatters.state',
  'cosmic-ui.formatters.status',
  'cosmic-ui.formatters.backends.conform',
  'cosmic-ui.formatters.backends.lsp',
  'cosmic-ui.formatters.ui.init',
}

local function reset_formatter_modules()
  for _, module_name in ipairs(formatter_modules) do
    package.loaded[module_name] = nil
  end
end

describe('cosmic-ui.formatters api', function()
  local original_notify = vim.notify
  local original_notify_once = vim.notify_once
  local original_get_clients = vim.lsp.get_clients
  local original_lsp_format = vim.lsp.buf.format
  local original_conform = package.loaded.conform
  local created_buffers
  local notifications
  local lsp_format_calls

  local function new_buffer(filetype)
    local bufnr = vim.api.nvim_create_buf(false, true)
    if filetype then
      vim.bo[bufnr].filetype = filetype
    end
    table.insert(created_buffers, bufnr)
    return bufnr
  end

  local function setup_formatters()
    reset_formatter_modules()
    local cosmic = require('cosmic-ui')
    cosmic.setup({ formatters = {} })
    return cosmic.formatters
  end

  local function warning_messages()
    local out = {}
    for _, notification in ipairs(notifications) do
      if notification.level == vim.log.levels.WARN then
        table.insert(out, notification.message)
      end
    end
    return out
  end

  local function error_messages()
    local out = {}
    for _, notification in ipairs(notifications) do
      if notification.level == vim.log.levels.ERROR then
        table.insert(out, notification.message)
      end
    end
    return out
  end

  local function lsp_client(id, name, supports_formatting)
    return {
      id = id,
      name = name,
      server_capabilities = {
        documentFormattingProvider = supports_formatting,
      },
      supports_method = function(_, method)
        return method == 'textDocument/formatting' and supports_formatting
      end,
    }
  end

  local function stub_conform(formatters, format_impl, extra)
    local conform = extra or {}
    conform.list_formatters_to_run = conform.list_formatters_to_run or function()
      return formatters
    end
    conform.format = format_impl
      or function(opts, cb)
        if cb then
          cb(nil)
        end
        return opts
      end
    package.loaded.conform = conform
    return conform
  end

  before_each(function()
    created_buffers = {}
    notifications = {}
    lsp_format_calls = {}
    package.loaded.conform = nil
    reset_formatter_modules()

    vim.notify = function(message, level, opts)
      table.insert(notifications, {
        kind = 'notify',
        message = message,
        level = level,
        opts = opts,
      })
    end

    vim.notify_once = function(message, level, opts)
      table.insert(notifications, {
        kind = 'notify_once',
        message = message,
        level = level,
        opts = opts,
      })
    end

    vim.lsp.get_clients = function()
      return {}
    end

    vim.lsp.buf.format = function(opts)
      table.insert(lsp_format_calls, opts)
    end
  end)

  after_each(function()
    for _, bufnr in ipairs(created_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end

    vim.notify = original_notify
    vim.notify_once = original_notify_once
    vim.lsp.get_clients = original_get_clients
    vim.lsp.buf.format = original_lsp_format
    package.loaded.conform = original_conform
    reset_formatter_modules()
  end)

  it('keeps global and buffer backend state separate', function()
    local formatters = setup_formatters()
    local first = new_buffer()
    local second = new_buffer()

    assert.are.same({
      lsp = true,
      conform = true,
    }, formatters.is_enabled({ scope = 'global', bufnr = first }))

    formatters.disable({ backend = 'lsp', scope = 'global', bufnr = first })

    assert.is_false(formatters.is_enabled({ backend = 'lsp', scope = 'global', bufnr = first }))
    assert.is_false(formatters.is_enabled({ backend = 'lsp', scope = 'buffer', bufnr = first }))
    assert.is_false(formatters.is_enabled({ backend = 'lsp', scope = 'buffer', bufnr = second }))

    formatters.enable({ backend = 'lsp', scope = 'buffer', bufnr = first })

    assert.is_true(formatters.is_enabled({ backend = 'lsp', scope = 'buffer', bufnr = first }))
    assert.is_false(formatters.is_enabled({ backend = 'lsp', scope = 'buffer', bufnr = second }))

    formatters.reset({ backend = 'lsp', scope = 'buffer', bufnr = first })

    assert.is_false(formatters.is_enabled({ backend = 'lsp', scope = 'buffer', bufnr = first }))

    formatters.reset({ backend = 'lsp', scope = 'global', bufnr = first })

    assert.is_true(formatters.is_enabled({ backend = 'lsp', scope = 'global', bufnr = first }))
    assert.is_true(formatters.is_enabled({ backend = 'lsp', scope = 'buffer', bufnr = second }))
  end)

  it('keeps item overrides scoped by source, name, scope, and buffer', function()
    local formatters = setup_formatters()
    local first = new_buffer()
    local second = new_buffer()

    formatters.disable_item({ source = 'conform', name = 'stylua', scope = 'global', bufnr = first })

    assert.is_false(
      formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'global', bufnr = first })
    )
    assert.is_false(
      formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = first })
    )
    assert.is_false(
      formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = second })
    )

    formatters.enable_item({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = first })
    formatters.disable_item({ source = 'lsp', name = 'lua_ls', scope = 'buffer', bufnr = first })

    assert.is_true(formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = first }))
    assert.is_false(
      formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = second })
    )
    assert.is_false(formatters.is_item_enabled({ source = 'lsp', name = 'lua_ls', scope = 'buffer', bufnr = first }))
    assert.is_true(formatters.is_item_enabled({ source = 'lsp', name = 'lua_ls', scope = 'buffer', bufnr = second }))

    formatters.reset({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = first })

    assert.is_false(
      formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = first })
    )

    formatters.reset({ source = 'conform', scope = 'global', bufnr = first })

    assert.is_true(formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'global', bufnr = first }))
    assert.is_true(
      formatters.is_item_enabled({ source = 'conform', name = 'stylua', scope = 'buffer', bufnr = second })
    )
  end)

  it('warns and returns nil or false for invalid public inputs', function()
    local formatters = setup_formatters()
    local bufnr = new_buffer()

    assert.is_nil(formatters.disable({ scope = 'workspace', bufnr = bufnr }))
    assert.is_nil(formatters.enable({ backend = 'none', bufnr = bufnr }))
    assert.is_nil(formatters.toggle_item({ source = 'unknown', name = 'stylua', bufnr = bufnr }))
    assert.is_nil(formatters.toggle_item({ source = 'conform', name = '', bufnr = bufnr }))
    assert.is_nil(formatters.is_enabled({ bufnr = 'current' }))
    assert.is_nil(formatters.format({ backend = {}, bufnr = bufnr }))
    assert.is_false(formatters.format({ backend = 'lsp', bufnr = bufnr }))

    assert.is_true(#warning_messages() >= 7)
  end)

  it('routes LSP formatting through a filter for enabled formatting clients', function()
    local formatters = setup_formatters()
    local bufnr = new_buffer()
    local lua_ls = lsp_client(1, 'lua_ls', true)
    local eslint = lsp_client(2, 'eslint', false)

    vim.lsp.get_clients = function(opts)
      assert.are.equal(bufnr, opts.bufnr)
      return { eslint, lua_ls }
    end

    assert.is_true(formatters.format({ backend = 'lsp', bufnr = bufnr, lsp = { timeout_ms = 1000 } }))

    assert.are.equal(1, #lsp_format_calls)
    assert.are.equal(bufnr, lsp_format_calls[1].bufnr)
    assert.is_false(lsp_format_calls[1].async)
    assert.are.equal(1000, lsp_format_calls[1].timeout_ms)
    assert.is_true(lsp_format_calls[1].filter(lua_ls))
    assert.is_false(lsp_format_calls[1].filter(eslint))
  end)

  it('excludes disabled LSP items from the formatting filter', function()
    local formatters = setup_formatters()
    local bufnr = new_buffer()
    local lua_ls = lsp_client(1, 'lua_ls', true)
    local tsserver = lsp_client(2, 'tsserver', true)

    vim.lsp.get_clients = function()
      return { tsserver, lua_ls }
    end

    formatters.disable_item({ source = 'lsp', name = 'lua_ls', bufnr = bufnr })

    assert.is_true(formatters.format({ backend = 'lsp', bufnr = bufnr }))

    assert.are.equal(1, #lsp_format_calls)
    assert.is_false(lsp_format_calls[1].filter(lua_ls))
    assert.is_true(lsp_format_calls[1].filter(tsserver))
  end)

  it('returns false and warns when no LSP clients are eligible', function()
    local formatters = setup_formatters()
    local bufnr = new_buffer()
    local eslint = lsp_client(1, 'eslint', false)

    vim.lsp.get_clients = function()
      return { eslint }
    end

    assert.is_false(formatters.format({ backend = 'lsp', bufnr = bufnr }))

    assert.are.equal(0, #lsp_format_calls)
    assert.is_true(
      vim.tbl_contains(warning_messages(), 'LSP formatting unavailable (all attached clients disabled or unsupported).')
    )
  end)

  it('filters Conform formatters by enabled item state and explicit formatter options', function()
    local conform_calls = {}
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')

    stub_conform({ 'stylua', 'prettier' }, function(opts)
      table.insert(conform_calls, opts)
    end)

    formatters.disable_item({ source = 'conform', name = 'prettier', bufnr = bufnr })

    assert.is_true(formatters.format({
      backend = 'conform',
      bufnr = bufnr,
      conform = {
        formatters = { 'prettier', 'stylua', 'unknown' },
      },
    }))

    assert.are.equal(1, #conform_calls)
    assert.are.same({ 'stylua' }, conform_calls[1].formatters)
    assert.are.equal('never', conform_calls[1].lsp_format)
  end)

  it('clamps Conform LSP mode to never when the LSP backend is disabled', function()
    local conform_calls = {}
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')

    stub_conform({ 'stylua' }, function(opts)
      table.insert(conform_calls, opts)
    end, {
      default_format_opts = {
        lsp_format = 'prefer',
      },
    })

    formatters.disable({ backend = 'lsp', bufnr = bufnr })

    assert.is_true(formatters.format({
      backend = { 'conform', 'lsp' },
      bufnr = bufnr,
    }))

    assert.are.equal(1, #conform_calls)
    assert.are.equal('never', conform_calls[1].lsp_format)
  end)

  it('uses Conform LSP fallback filters for enabled LSP clients and user filters', function()
    local conform_calls = {}
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')
    local eslint = lsp_client(1, 'eslint', true)
    local lua_ls = lsp_client(2, 'lua_ls', true)
    local tsserver = lsp_client(3, 'tsserver', true)

    vim.lsp.get_clients = function()
      return { tsserver, lua_ls, eslint }
    end

    stub_conform({ 'stylua' }, function(opts)
      table.insert(conform_calls, opts)
    end)

    formatters.disable_item({ source = 'lsp', name = 'tsserver', bufnr = bufnr })

    assert.is_true(formatters.format({
      backend = { 'conform', 'lsp' },
      bufnr = bufnr,
      conform = {
        lsp_format = 'prefer',
        filter = function(client)
          return client.name ~= 'lua_ls'
        end,
      },
    }))

    assert.are.equal(1, #conform_calls)
    assert.are.equal('function', type(conform_calls[1].filter))
    assert.is_true(conform_calls[1].filter(eslint))
    assert.is_false(conform_calls[1].filter(lua_ls))
    assert.is_false(conform_calls[1].filter(tsserver))
  end)

  it('reports async Conform callback errors through notifications without throwing', function()
    local conform_calls = {}
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')

    stub_conform({ 'stylua' }, function(opts, cb)
      table.insert(conform_calls, opts)
      cb('format failed')
    end)

    assert.is_true(formatters.format_async({ backend = 'conform', bufnr = bufnr }))

    assert.are.equal(1, #conform_calls)
    assert.are.same({ 'stylua' }, conform_calls[1].formatters)
    assert.is_true(vim.tbl_contains(error_messages(), 'Conform format failed: format failed'))
  end)

  it('discovers Conform formatters once when building a status snapshot', function()
    local conform_discovery_calls = 0
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')

    stub_conform(nil, nil, {
      list_formatters_to_run = function(target_bufnr)
        assert.are.equal(bufnr, target_bufnr)
        conform_discovery_calls = conform_discovery_calls + 1
        return { 'stylua' }
      end,
      default_format_opts = {
        lsp_format = 'fallback',
      },
      formatters_by_ft = {
        lua = { 'stylua' },
      },
    })

    local snapshot = formatters.status({ bufnr = bufnr })

    assert.are.equal(1, conform_discovery_calls)
    assert.is_not_nil(snapshot.backends.conform.state)
    assert.are.equal(1, #snapshot.conform.formatters)
    assert.are.equal('stylua', snapshot.conform.formatters[1].name)
    assert.is_not_nil(snapshot.conform.fallback)
  end)
end)
