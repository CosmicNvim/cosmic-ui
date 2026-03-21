describe('cosmic-ui.codeactions.ui', function()
  local lifecycle

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
end)
