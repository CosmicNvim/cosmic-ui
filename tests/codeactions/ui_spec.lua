describe('cosmic-ui.codeactions.ui', function()
  local lifecycle

  local function collect_highlights(bufnr, ns)
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true })
    local collected = {}

    for _, mark in ipairs(marks) do
      table.insert(collected, {
        lnum = mark[2],
        col = mark[3],
        end_col = mark[4].end_col,
        hl_group = mark[4].hl_group,
      })
    end

    return collected
  end

  before_each(function()
    lifecycle = require('cosmic-ui.codeactions.ui.lifecycle')
    lifecycle.close_current()
  end)

  after_each(function()
    lifecycle.close_current()
  end)

  it('opens an explicit empty-state panel when no actions are available', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {},
      },
    }, {})

    local state = lifecycle.get_state()
    assert.is_not_nil(state.ui)
    assert.is_true(vim.api.nvim_buf_is_valid(state.ui.buf))
    assert.is_true(
      vim.tbl_contains(vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false), ' No code actions available ')
    )
  end)

  it('requests normal-mode normalization when opened outside normal mode', function()
    local ui = require('cosmic-ui.codeactions.ui')
    local original_mode = vim.fn.mode
    local original_input = vim.api.nvim_input
    local seen = {}

    vim.fn.mode = function()
      return 'i'
    end
    vim.api.nvim_input = function(keys)
      table.insert(seen, keys)
      return ''
    end

    local ok, err = pcall(function()
      ui.open({
        [1] = {
          client = { id = 1, name = 'lua_ls' },
          result = {
            { title = 'Fix' },
          },
        },
      }, {})
    end)

    vim.fn.mode = original_mode
    vim.api.nvim_input = original_input

    if not ok then
      error(err)
    end

    ui.close()
    assert.are.same({ '<Esc>' }, seen)
  end)

  it('highlights footer helpers from the first character', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {},
      },
    }, {})

    local state = lifecycle.get_state()
    local lines = vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false)
    local marks = collect_highlights(state.ui.buf, state.ui.ns)
    local footer_marks = {}

    assert.are.equal(' Esc:close ', lines[#lines])

    for _, mark in ipairs(marks) do
      if mark.lnum == #lines - 1 then
        table.insert(footer_marks, mark)
      end
    end

    table.sort(footer_marks, function(left, right)
      return left.col < right.col
    end)

    assert.are.same({
      {
        lnum = #lines - 1,
        col = 1,
        end_col = 4,
        hl_group = 'CosmicUiPanelHintKey',
      },
      {
        lnum = #lines - 1,
        col = 5,
        end_col = 10,
        hl_group = 'CosmicUiPanelHintText',
      },
    }, footer_marks)
  end)

  it('preserves configured min width and border metadata on the float', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix' },
        },
      },
    }, {
      min_width = 50,
      border = {
        style = 'single',
        title = 'Custom Actions',
        title_align = 'left',
        title_hl = 'Title',
        bottom_hl = 'Question',
        highlight = 'Identifier',
      },
    })

    local state = lifecycle.get_state()
    local cfg = vim.api.nvim_win_get_config(state.ui.win)

    assert.are.equal(52, cfg.width)
    assert.are.equal('table', type(cfg.border))
    assert.are.equal('┌', cfg.border[1])
    assert.are.equal('Custom Actions', cfg.title[1][1])
    assert.are.equal('left', cfg.title_pos)
    assert.are.equal('(1/1)', cfg.footer[1][1])
    assert.are.equal('right', cfg.footer_pos)
    assert.is_true(string.find(vim.wo[state.ui.win].winhl, 'FloatBorder:Identifier', 1, true) ~= nil)
    assert.is_true(string.find(vim.wo[state.ui.win].winhl, 'FloatTitle:Title', 1, true) ~= nil)
    assert.is_true(string.find(vim.wo[state.ui.win].winhl, 'FloatFooter:Question', 1, true) ~= nil)
  end)

  it('does not reopen a dismissed loading panel when ready-state results arrive for the same request', function()
    local ui = require('cosmic-ui.codeactions.ui')

    local request_state = {
      status = 'loading',
      responses = {},
      total_clients = 1,
      completed_clients = 0,
    }

    ui.open(request_state, {})
    assert.is_not_nil(lifecycle.get_state().ui)

    ui.close()
    assert.is_nil(lifecycle.get_state().ui)

    request_state.status = 'ready'
    request_state.completed_clients = 1
    request_state.responses[1] = {
      client = { id = 1, name = 'lua_ls' },
      result = {
        { title = 'Fix' },
      },
    }

    ui.open(request_state, {})

    assert.is_nil(lifecycle.get_state().ui)
  end)

  it('reopens after a loading panel loses focus while the request is still in flight', function()
    local ui = require('cosmic-ui.codeactions.ui')

    local request_state = {
      status = 'loading',
      responses = {},
      total_clients = 1,
      completed_clients = 0,
    }

    ui.open(request_state, {})
    assert.is_not_nil(lifecycle.get_state().ui)

    local buf = lifecycle.get_state().ui.buf
    vim.api.nvim_exec_autocmds('BufLeave', { buffer = buf })

    assert.is_nil(lifecycle.get_state().ui)
    assert.is_false(lifecycle.is_request_dismissed(request_state))

    request_state.status = 'ready'
    request_state.completed_clients = 1
    request_state.responses[1] = {
      client = { id = 1, name = 'lua_ls' },
      result = {
        { title = 'Fix' },
      },
    }

    ui.open(request_state, {})

    local state = lifecycle.get_state()
    assert.is_not_nil(state.ui)
    assert.is_true(vim.tbl_contains(vim.api.nvim_buf_get_lines(state.ui.buf, 0, -1, false), ' 1. Fix '))
  end)

  it('keeps explicit dismiss semantics when a ready panel is reused for a new loading request', function()
    local ui = require('cosmic-ui.codeactions.ui')

    ui.open({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {
          { title = 'Fix A' },
        },
      },
    }, {})

    local request_state = {
      status = 'loading',
      responses = {},
      total_clients = 1,
      completed_clients = 0,
    }

    ui.open(request_state, {})
    assert.are.equal(request_state, lifecycle.get_state().ui.request_state)

    ui.close()
    assert.is_nil(lifecycle.get_state().ui)

    request_state.status = 'ready'
    request_state.completed_clients = 1
    request_state.responses[1] = {
      client = { id = 1, name = 'lua_ls' },
      result = {
        { title = 'Fix B' },
      },
    }

    ui.open(request_state, {})

    assert.is_nil(lifecycle.get_state().ui)
  end)

  it('supports numeric direct picks for the first visible actions', function()
    local input = require('cosmic-ui.codeactions.ui.input')

    local buf = vim.api.nvim_create_buf(false, true)
    local win = vim.api.nvim_get_current_win()
    local selected
    local closed = 0

    local ui = {
      buf = buf,
      win = win,
      selected = 1,
      model = {
        actions = {
          { text = 'First action' },
          { text = 'Second action' },
          { text = 'Third action' },
        },
      },
    }

    input.set_keymaps(ui, {
      submit_action = function(action)
        selected = action.text
      end,
    }, {
      close_fn = function()
        closed = closed + 1
      end,
      render_fn = function() end,
    })

    vim.api.nvim_set_current_win(win)
    vim.api.nvim_set_current_buf(buf)
    vim.api.nvim_feedkeys('2', 'xt', false)

    assert.are.equal('Second action', selected)
    assert.are.equal(1, closed)
  end)
end)

describe('cosmic-ui.codeactions.request', function()
  it('reports loading before ready and keeps request metadata', function()
    local request = require('cosmic-ui.codeactions.request')
    local original_get_namespace = vim.lsp.diagnostic.get_namespace
    local original_diagnostic_get = vim.diagnostic.get
    local original_make_range_params = vim.lsp.util.make_range_params
    local callbacks = {}
    local seen = {}

    vim.lsp.diagnostic.get_namespace = function()
      return 0
    end
    vim.diagnostic.get = function()
      return {}
    end
    vim.lsp.util.make_range_params = function()
      return { context = {} }
    end

    local clients = {
      {
        id = 1,
        name = 'lua_ls',
        offset_encoding = 'utf-16',
        request = function(_, _, _, cb)
          callbacks[1] = cb
        end,
      },
      {
        id = 2,
        name = 'eslint',
        offset_encoding = 'utf-16',
        request = function(_, _, _, cb)
          callbacks[2] = cb
        end,
      },
    }

    local ok, err = pcall(function()
      request.collect({
        bufnr = 0,
        clients = clients,
        user_opts = { params = { context = { only = { 'quickfix' } } } },
        on_complete = function(state)
          table.insert(seen, {
            status = state.status,
            total_clients = state.total_clients,
            completed_clients = state.completed_clients,
            response_count = vim.tbl_count(state.responses),
          })
        end,
      })

      callbacks[1](nil, { { title = 'Fix one' } })
      callbacks[2](nil, { { title = 'Fix two' } })
    end)

    vim.lsp.diagnostic.get_namespace = original_get_namespace
    vim.diagnostic.get = original_diagnostic_get
    vim.lsp.util.make_range_params = original_make_range_params

    assert.is_true(ok, err)
    assert.are.same({
      {
        status = 'loading',
        total_clients = 2,
        completed_clients = 0,
        response_count = 0,
      },
      {
        status = 'ready',
        total_clients = 2,
        completed_clients = 2,
        response_count = 2,
      },
    }, seen)
  end)

  it('freezes the source buffer before the loading callback changes current buffer', function()
    local request = require('cosmic-ui.codeactions.request')
    local original_get_namespace = vim.lsp.diagnostic.get_namespace
    local original_diagnostic_get = vim.diagnostic.get
    local original_make_range_params = vim.lsp.util.make_range_params
    local seen = {}

    vim.lsp.diagnostic.get_namespace = function()
      return 0
    end
    vim.diagnostic.get = function()
      return {}
    end
    vim.lsp.util.make_range_params = function(_, _)
      return {
        textDocument = {
          uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf()),
        },
        context = {},
      }
    end

    local ok, err = pcall(function()
      vim.cmd('enew!')
      local source_buf = vim.api.nvim_get_current_buf()
      local source_name = vim.fn.tempname() .. '.ts'
      vim.api.nvim_buf_set_name(source_buf, source_name)
      local scratch_buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_name(scratch_buf, 'scratch://loading')

      request.collect({
        bufnr = 0,
        clients = {
          {
            id = 1,
            name = 'lua_ls',
            offset_encoding = 'utf-16',
            request = function(_, _, params, cb, bufnr)
              table.insert(seen, {
                bufnr = bufnr,
                current_buf = vim.api.nvim_get_current_buf(),
                uri = params.textDocument and params.textDocument.uri or nil,
              })
              cb(nil, {})
            end,
          },
        },
        on_complete = function(state)
          if state.status == 'loading' then
            vim.api.nvim_set_current_buf(scratch_buf)
          end
        end,
      })

      assert.are.same({
        {
          bufnr = source_buf,
          current_buf = scratch_buf,
          uri = vim.uri_from_bufnr(source_buf),
        },
      }, seen)
    end)

    vim.lsp.diagnostic.get_namespace = original_get_namespace
    vim.diagnostic.get = original_diagnostic_get
    vim.lsp.util.make_range_params = original_make_range_params

    assert.is_true(ok, err)
  end)
end)
