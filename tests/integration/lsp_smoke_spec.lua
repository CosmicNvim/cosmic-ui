describe('cosmic-ui public API headless LSP smoke', function()
  local source_buf
  local source_win
  local original_buf
  local original_win
  local client_id
  local rpc_state
  local original_notify
  local original_notify_once
  local original_guicursor
  local original_conform
  local original_conform_preload
  local original_devicons

  local function press(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), 'xt', false)
    vim.cmd('redraw')
  end

  local function wait_for(predicate, message)
    assert.is_true(vim.wait(3000, predicate, 10), message)
  end

  local function buffer_contains(bufnr, needle)
    if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then
      return false
    end

    for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      if line:find(needle, 1, true) then
        return true
      end
    end

    return false
  end

  local function workspace_edit(uri, edits)
    return {
      changes = {
        [uri] = edits,
      },
    }
  end

  local function text_edit(start_line, start_col, end_line, end_col, new_text)
    return {
      range = {
        start = { line = start_line, character = start_col },
        ['end'] = { line = end_line, character = end_col },
      },
      newText = new_text,
    }
  end

  local function response_for(method, params)
    local uri = vim.uri_from_bufnr(source_buf)

    local function assert_source_document()
      assert(params.textDocument, ('%s request is missing textDocument'):format(method))
      assert(
        params.textDocument.uri == uri,
        ('%s request targeted the wrong buffer (expected %s, got %s)'):format(
          method,
          uri,
          tostring(params.textDocument.uri)
        )
      )
    end

    if method == 'initialize' then
      return {
        capabilities = {
          textDocumentSync = 1,
          renameProvider = true,
          codeActionProvider = { resolveProvider = true },
          documentFormattingProvider = true,
          positionEncoding = 'utf-16',
        },
        serverInfo = {
          name = 'cosmic-ui-headless-smoke',
          version = '1',
        },
      }
    end

    if method == 'textDocument/rename' then
      assert_source_document()
      assert(params.newName == 'cafe', 'rename request used the wrong new name')
      assert(params.position.line == 0 and params.position.character == 6, 'rename request used the wrong position')
      return workspace_edit(uri, {
        text_edit(0, 6, 0, 11, params.newName),
        text_edit(1, 6, 1, 11, params.newName),
      })
    end

    if method == 'textDocument/codeAction' then
      assert_source_document()
      assert(
        params.range.start.line == 0 and params.range.start.character == 0,
        'code action used the wrong range start'
      )
      assert(
        params.range['end'].line == 0 and params.range['end'].character == 0,
        'code action used the wrong range end'
      )
      assert(vim.islist(params.context.diagnostics), 'code action request is missing diagnostics context')
      return {
        {
          title = 'Set the answer',
          data = { smoke = true },
        },
      }
    end

    if method == 'codeAction/resolve' then
      assert(params.title == 'Set the answer', 'code action resolve used the wrong action')
      assert(params.data and params.data.smoke == true, 'code action resolve dropped action data')
      local line = vim.api.nvim_buf_get_lines(source_buf, 0, 1, false)[1]
      local answer_col = assert(line:find('0', 1, true)) - 1
      return {
        title = params.title,
        edit = workspace_edit(uri, {
          text_edit(0, answer_col, 0, answer_col + 1, '42'),
        }),
      }
    end

    if method == 'textDocument/formatting' then
      assert_source_document()
      local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
      return {
        text_edit(0, 0, #lines - 1, #lines[#lines], lines[1] .. ' -- formatted\n' .. lines[2]),
      }
    end

    if method == 'shutdown' then
      return nil
    end

    error(('unexpected LSP request: %s'):format(method))
  end

  local function make_rpc_client(dispatchers)
    local request_id = 0
    local closing = false
    local exited = false

    local function exit_once()
      if exited then
        return
      end

      exited = true
      closing = true
      vim.schedule(function()
        dispatchers.on_exit(0, 0)
      end)
    end

    return {
      request = function(method, params, callback, notify_reply_callback)
        request_id = request_id + 1
        local id = request_id
        table.insert(rpc_state.requests, {
          method = method,
          params = params,
        })
        local ok, result = pcall(response_for, method, params)
        if not ok then
          rpc_state.response_error = result
        end

        vim.schedule(function()
          if ok then
            callback(nil, result, id)
          else
            callback({ code = -32603, message = result }, nil, id)
          end
          if notify_reply_callback then
            notify_reply_callback(id)
          end
        end)

        return true, id
      end,
      notify = function(method, params)
        table.insert(rpc_state.notifications, {
          method = method,
          params = params,
        })
        if method == 'exit' then
          exit_once()
        end
        return true
      end,
      is_closing = function()
        return closing
      end,
      terminate = exit_once,
    }
  end

  local function close_plugin_floats()
    local codeaction_lifecycle = package.loaded['cosmic-ui.codeactions.ui.lifecycle']
    if codeaction_lifecycle then
      pcall(codeaction_lifecycle.close_current)
    end

    local formatter_lifecycle = package.loaded['cosmic-ui.formatters.ui.lifecycle']
    if formatter_lifecycle then
      pcall(formatter_lifecycle.close_current)
    end

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= '' then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end

  before_each(function()
    original_buf = vim.api.nvim_get_current_buf()
    original_win = vim.api.nvim_get_current_win()
    original_notify = vim.notify
    original_notify_once = vim.notify_once
    original_guicursor = vim.o.guicursor
    original_conform = package.loaded.conform
    original_conform_preload = package.preload.conform
    original_devicons = package.loaded['nvim-web-devicons']
    rpc_state = {
      requests = {},
      notifications = {},
    }

    vim.notify = function() end
    vim.notify_once = function() end

    source_buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(source_buf, vim.fn.tempname() .. '.lua')
    vim.api.nvim_buf_set_lines(source_buf, 0, -1, false, {
      'local value = 0',
      'print(value)',
    })
    vim.bo[source_buf].filetype = 'lua'
    vim.api.nvim_set_current_buf(source_buf)
    source_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_cursor(source_win, { 1, 6 })
  end)

  after_each(function()
    pcall(vim.cmd, 'stopinsert')
    close_plugin_floats()

    if client_id then
      local client = vim.lsp.get_client_by_id(client_id)
      if client then
        client:stop(true)
        local stopped = vim.wait(1000, function()
          return vim.lsp.get_client_by_id(client_id) == nil
        end, 10)
        assert.is_true(stopped, 'headless LSP client did not stop cleanly')
      end
      client_id = nil
    end

    if original_win and vim.api.nvim_win_is_valid(original_win) then
      vim.api.nvim_set_current_win(original_win)
    end
    if original_buf and vim.api.nvim_buf_is_valid(original_buf) then
      vim.api.nvim_set_current_buf(original_buf)
    end
    if source_buf and vim.api.nvim_buf_is_valid(source_buf) then
      vim.api.nvim_buf_delete(source_buf, { force = true })
    end

    package.loaded.conform = original_conform
    package.preload.conform = original_conform_preload
    package.loaded['nvim-web-devicons'] = original_devicons
    vim.notify = original_notify
    vim.notify_once = original_notify_once
    vim.o.guicursor = original_guicursor
  end)

  it('runs rename, code actions, and formatting through a real attached client and native floats', function()
    client_id = assert(vim.lsp.start({
      name = 'cosmic-ui-headless-smoke-' .. tostring(source_buf),
      cmd = function(dispatchers)
        return make_rpc_client(dispatchers)
      end,
      root_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(source_buf)),
    }, {
      bufnr = source_buf,
      reuse_client = function()
        return false
      end,
    }))

    wait_for(function()
      local client = vim.lsp.get_client_by_id(client_id)
      return client and client.initialized and client.attached_buffers[source_buf]
    end, 'headless LSP client did not initialize and attach')

    local cosmic = require('cosmic-ui')
    cosmic.setup({
      rename = {},
      codeactions = {},
      formatters = {},
    })

    cosmic.rename.open({ default_value = 'café' })
    local rename_buf = vim.api.nvim_get_current_buf()
    assert.are.equal('cosmicui-rename', vim.bo[rename_buf].filetype)
    press('A<BS>')
    assert.are.same({ '> caf' }, vim.api.nvim_buf_get_lines(rename_buf, 0, -1, false))
    press('Ae')
    assert.are.same({ '> cafe' }, vim.api.nvim_buf_get_lines(rename_buf, 0, -1, false))
    press('<CR>')

    wait_for(function()
      return vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)[1] == 'local cafe = 0'
    end, 'rename workspace edit was not applied')
    assert.are.same({
      'local cafe = 0',
      'print(cafe)',
    }, vim.api.nvim_buf_get_lines(source_buf, 0, -1, false))
    assert.is_false(vim.api.nvim_buf_is_valid(rename_buf))
    assert.are.equal(source_buf, vim.api.nvim_get_current_buf())

    local action_range = {
      start = { line = 0, character = 0 },
      ['end'] = { line = 0, character = 0 },
    }
    cosmic.codeactions.open({
      params = {
        textDocument = { uri = vim.uri_from_bufnr(source_buf) },
        range = action_range,
        context = { diagnostics = {} },
      },
    })

    local codeaction_lifecycle = require('cosmic-ui.codeactions.ui.lifecycle')
    local loading_ui = assert(codeaction_lifecycle.get_state().ui)
    local codeaction_buf = loading_ui.buf
    assert.is_true(buffer_contains(codeaction_buf, 'Loading code actions...'))

    wait_for(function()
      local ui = codeaction_lifecycle.get_state().ui
      return ui and ui.buf == codeaction_buf and buffer_contains(ui.buf, 'Set the answer')
    end, 'code action panel did not transition from loading to ready')
    press('<CR>')

    wait_for(function()
      return vim.api.nvim_buf_get_lines(source_buf, 0, 1, false)[1] == 'local cafe = 42'
    end, 'resolved code action edit was not applied')
    assert.is_false(vim.api.nvim_buf_is_valid(codeaction_buf))
    assert.are.equal(source_buf, vim.api.nvim_get_current_buf())

    package.loaded['nvim-web-devicons'] = {
      get_icon_by_filetype = function()
        return 'F'
      end,
      get_icon = function()
        return 'I'
      end,
    }
    package.loaded.conform = nil
    package.preload.conform = function()
      error('Conform intentionally unavailable in LSP smoke test')
    end

    cosmic.formatters.open({ bufnr = source_buf })
    local formatter_lifecycle = require('cosmic-ui.formatters.ui.lifecycle')
    local formatter_ui = assert(formatter_lifecycle.get_state().ui)
    local formatter_buf = formatter_ui.buf
    assert.are.equal('cosmicui-formatters', vim.bo[formatter_buf].filetype)
    assert.is_true(buffer_contains(formatter_buf, 'cosmic-ui-headless-smoke'))

    press('<Tab>')
    assert.is_false(cosmic.formatters.is_item_enabled({
      source = 'lsp',
      name = 'cosmic-ui-headless-smoke-' .. tostring(source_buf),
      bufnr = source_buf,
    }))
    press('<Tab>')
    assert.is_true(cosmic.formatters.is_item_enabled({
      source = 'lsp',
      name = 'cosmic-ui-headless-smoke-' .. tostring(source_buf),
      bufnr = source_buf,
    }))
    press('f')

    wait_for(function()
      return rpc_state.response_error
        or vim.api.nvim_buf_get_lines(source_buf, 0, 1, false)[1] == 'local cafe = 42 -- formatted'
    end, 'LSP formatting edits were not applied')
    assert.is_nil(rpc_state.response_error, rpc_state.response_error)
    assert.is_false(vim.api.nvim_buf_is_valid(formatter_buf))
    assert.is_nil(formatter_lifecycle.get_state().ui)
    assert.are.equal(original_guicursor, vim.o.guicursor)

    local counts = {}
    for _, request in ipairs(rpc_state.requests) do
      counts[request.method] = (counts[request.method] or 0) + 1
    end
    assert.are.equal(1, counts.initialize)
    assert.are.equal(1, counts['textDocument/rename'])
    assert.are.equal(1, counts['textDocument/codeAction'])
    assert.are.equal(1, counts['codeAction/resolve'])
    assert.are.equal(1, counts['textDocument/formatting'])
  end)
end)
