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
  local lsp_format_buffers

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
    lsp_format_buffers = {}
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
      table.insert(lsp_format_buffers, vim.api.nvim_get_current_buf())
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
    assert.are.equal(bufnr, lsp_format_buffers[1])
    assert.is_true(lsp_format_calls[1].filter(lua_ls))
    assert.is_false(lsp_format_calls[1].filter(eslint))
  end)

  it('keeps every async LSP request tied to the target buffer', function()
    local formatters = setup_formatters()
    local target_bufnr = new_buffer('lua')
    local other_bufnr = new_buffer('lua')
    local callbacks = {}
    local requests = {}

    vim.bo[target_bufnr].shiftwidth = 2
    vim.bo[target_bufnr].expandtab = true
    vim.bo[other_bufnr].shiftwidth = 8
    vim.bo[other_bufnr].expandtab = false

    local function async_client(id, name)
      return {
        id = id,
        name = name,
        offset_encoding = 'utf-16',
        handlers = {},
        server_capabilities = { documentFormattingProvider = true },
        supports_method = function(_, method, bufnr)
          return method == 'textDocument/formatting' and bufnr == target_bufnr
        end,
        request = function(_, method, params, callback, bufnr)
          table.insert(requests, {
            name = name,
            method = method,
            params = params,
            bufnr = bufnr,
          })
          callbacks[name] = callback
          return true
        end,
      }
    end

    local first = async_client(1, 'first')
    local second = async_client(2, 'second')
    vim.lsp.get_clients = function(opts)
      assert.are.equal(target_bufnr, opts.bufnr)
      return { second, first }
    end

    vim.api.nvim_set_current_buf(target_bufnr)
    assert.is_true(formatters.format_async({ backend = 'lsp', bufnr = target_bufnr }))
    assert.are.equal(1, #requests)
    assert.are.equal('first', requests[1].name)

    vim.api.nvim_set_current_buf(other_bufnr)
    callbacks.first(nil, nil, { client_id = first.id, bufnr = target_bufnr })

    assert.are.equal(2, #requests)
    assert.are.equal('second', requests[2].name)
    for _, request in ipairs(requests) do
      assert.are.equal('textDocument/formatting', request.method)
      assert.are.equal(target_bufnr, request.bufnr)
      assert.are.equal(vim.uri_from_bufnr(target_bufnr), request.params.textDocument.uri)
      assert.are.equal(2, request.params.options.tabSize)
      assert.is_true(request.params.options.insertSpaces)
    end

    callbacks.second(nil, nil, { client_id = second.id, bufnr = target_bufnr })
  end)

  it('uses range formatting clients when a range is requested', function()
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')
    local seen
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { 'hello world' })
    local range_client = {
      id = 1,
      name = 'range-only',
      offset_encoding = 'utf-16',
      handlers = {},
      server_capabilities = {
        documentFormattingProvider = false,
        documentRangeFormattingProvider = true,
      },
      supports_method = function(_, method)
        return method == 'textDocument/rangeFormatting'
      end,
      request = function(_, method, params, callback, target_bufnr)
        seen = {
          method = method,
          params = params,
          bufnr = target_bufnr,
        }
        callback(nil, nil, { client_id = 1, bufnr = target_bufnr })
        return true
      end,
    }

    vim.lsp.get_clients = function(opts)
      assert.are.equal(bufnr, opts.bufnr)
      return { range_client }
    end

    assert.is_true(formatters.format_async({
      backend = 'lsp',
      bufnr = bufnr,
      lsp = {
        range = {
          start = { 1, 0 },
          ['end'] = { 1, 5 },
        },
      },
    }))

    assert.are.equal('textDocument/rangeFormatting', seen.method)
    assert.are.equal(bufnr, seen.bufnr)
    assert.are.equal(vim.uri_from_bufnr(bufnr), seen.params.textDocument.uri)
    local expected_end_character = vim.o.selection == 'exclusive' and 5 or 6
    assert.are.same({
      start = { line = 0, character = 0 },
      ['end'] = { line = 0, character = expected_end_character },
    }, seen.params.range)
  end)

  it('checks LSP formatting support for the target buffer', function()
    local formatters = setup_formatters()
    local target_bufnr = new_buffer('lua')
    local current_bufnr = new_buffer('text')
    local supports_bufnr
    local dynamic_client = {
      id = 1,
      name = 'dynamic-formatter',
      server_capabilities = {},
      supports_method = function(_, method, bufnr)
        supports_bufnr = bufnr
        return method == 'textDocument/formatting' and bufnr == target_bufnr
      end,
    }

    vim.api.nvim_set_current_buf(current_bufnr)
    vim.lsp.get_clients = function(opts)
      assert.are.equal(target_bufnr, opts.bufnr)
      return { dynamic_client }
    end

    local snapshot = formatters.status({ bufnr = target_bufnr })

    assert.are.equal(target_bufnr, supports_bufnr)
    assert.is_true(snapshot.lsp_clients[1].available)
    assert.is_true(snapshot.lsp_clients[1].effective_enabled)
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

  it('discovers Conform CLI formatters independently from configured LSP routing', function()
    local conform_calls = {}
    local discovery_calls = 0
    local routed_discovery_calls = 0
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')
    local lua_ls = lsp_client(1, 'lua_ls', true)

    vim.lsp.get_clients = function()
      return { lua_ls }
    end

    stub_conform(nil, function(opts)
      table.insert(conform_calls, opts)
    end, {
      list_formatters = function(target_bufnr)
        assert.are.equal(bufnr, target_bufnr)
        discovery_calls = discovery_calls + 1
        return { { name = 'stylua' } }
      end,
      list_formatters_to_run = function()
        routed_discovery_calls = routed_discovery_calls + 1
        return {}, true
      end,
      default_format_opts = {
        lsp_format = 'prefer',
      },
      formatters_by_ft = {
        lua = { 'stylua' },
      },
    })

    formatters.disable({ backend = 'lsp', bufnr = bufnr })
    discovery_calls = 0

    assert.is_true(formatters.format({
      backend = { 'conform', 'lsp' },
      bufnr = bufnr,
    }))

    assert.are.equal(1, discovery_calls)
    assert.are.equal(0, routed_discovery_calls)
    assert.are.equal(1, #conform_calls)
    assert.are.same({ 'stylua' }, conform_calls[1].formatters)
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

  it('reflects requested Conform LSP mode in status fallback metadata', function()
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')

    stub_conform({ 'stylua' })

    local snapshot = formatters.status({
      bufnr = bufnr,
      conform = {
        lsp_format = 'fallback',
      },
    })

    assert.are.equal('fallback', snapshot.conform.fallback.requested_mode)
    assert.are.equal('fallback', snapshot.conform.fallback.mode)
    assert.are.equal('requested', snapshot.conform.fallback.configured_source)
  end)

  it('ignores invalid requested Conform LSP mode in status fallback metadata', function()
    local formatters = setup_formatters()
    local bufnr = new_buffer('lua')

    stub_conform({ 'stylua' }, nil, {
      default_format_opts = {
        lsp_format = 'prefer',
      },
    })

    local snapshot = formatters.status({
      bufnr = bufnr,
      conform = {
        lsp_format = 'bad-mode',
      },
    })

    assert.is_nil(snapshot.conform.fallback.requested_mode)
    assert.are.equal('prefer', snapshot.conform.fallback.mode)
    assert.are.equal('global', snapshot.conform.fallback.configured_source)
  end)
end)
