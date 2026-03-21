describe('cosmic-ui.rename.model', function()
  it('rejects empty submissions without dispatching rename', function()
    local model = require('cosmic-ui.rename.model')
    local result = model.normalize_submission('> ', '> ', '> ')

    assert.are.same({ ok = false, reason = 'empty' }, result)
  end)

  it('rejects unchanged submissions', function()
    local model = require('cosmic-ui.rename.model')
    local result = model.normalize_submission('> ', '> current_name', 'current_name')

    assert.are.same({ ok = false, reason = 'unchanged' }, result)
  end)

  it('extracts the submitted value from the prompt line', function()
    local model = require('cosmic-ui.rename.model')

    assert.are.equal('next_name', model.extract_value('> ', '> next_name'))
    assert.are.equal('raw_name', model.extract_value('> ', 'raw_name'))
  end)
end)

describe('cosmic-ui.rename.ui', function()
  local original_get_clients
  local original_expand

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

  local function stub_rename_context(current_name)
    original_get_clients = vim.lsp.get_clients
    original_expand = vim.fn.expand

    vim.lsp.get_clients = function()
      return {
        { id = 1, name = 'lua_ls' },
      }
    end

    vim.fn.expand = function(expr)
      if expr == '<cword>' then
        return current_name
      end

      return original_expand(expr)
    end
  end

  local function restore_rename_context()
    if original_get_clients then
      vim.lsp.get_clients = original_get_clients
      original_get_clients = nil
    end

    if original_expand then
      vim.fn.expand = original_expand
      original_expand = nil
    end
  end

  local function press(keys)
    vim.api.nvim_feedkeys(vim.keycode(keys), 'xt', false)
  end

  after_each(function()
    restore_rename_context()

    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local config = vim.api.nvim_win_get_config(win)
      if config.relative ~= '' then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end

    vim.cmd('silent! only')
  end)

  it('restores focus to the origin window on submit', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')
    local origin_win = vim.api.nvim_get_current_win()
    local submitted

    vim.cmd('split')
    vim.api.nvim_set_current_win(origin_win)

    ui.open({
      default_value = 'next_name',
      on_submit = function(new_name)
        submitted = {
          name = new_name,
          win = vim.api.nvim_get_current_win(),
        }
      end,
    })

    press('<CR>')
    vim.wait(1000, function()
      return submitted ~= nil
    end)

    assert.are.equal(origin_win, vim.api.nvim_get_current_win())
    assert.are.same({
      name = 'next_name',
      win = origin_win,
    }, submitted)
  end)

  it('allows editing the prompt line before submit', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')
    local submitted

    ui.open({
      default_value = 'draft',
      on_submit = function(new_name)
        submitted = new_name
      end,
    })

    local buf = vim.api.nvim_get_current_buf()
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_text(buf, 2, 7, 2, 7, { '2' })
    vim.bo[buf].modifiable = false

    press('<CR>')
    vim.wait(1000, function()
      return submitted ~= nil
    end)

    assert.are.equal('draft2', submitted)
  end)

  it('locks the panel outside insert mode so helper lines cannot be edited', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')

    ui.open({
      default_value = 'next_name',
    })

    local buf = vim.api.nvim_get_current_buf()
    local before = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    vim.cmd('stopinsert')
    vim.wait(1000, function()
      return vim.fn.mode() == 'n'
    end)

    local ok = pcall(vim.cmd, 'normal! G0rx')
    local after = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    assert.is_false(vim.bo[buf].modifiable)
    assert.is_false(ok)
    assert.are.same(before, after)
  end)

  it('renders the default compact rename buffer as a single prompt line', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')

    ui.open({
      default_value = 'next_name',
    })

    local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)

    assert.are.same({ '> next_name' }, lines)
    assert.is_false(vim.tbl_contains(lines, ' Current: current_name '))
    assert.is_false(vim.tbl_contains(lines, ' Enter:rename  Esc:cancel '))
  end)

  it('preserves explicit window width and height overrides after render', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')

    ui.open({
      default_value = 'next_name',
      window = {
        width = 52,
        height = 7,
      },
    })

    local cfg = vim.api.nvim_win_get_config(vim.api.nvim_get_current_win())

    assert.are.equal(52, cfg.width)
    assert.are.equal(7, cfg.height)
  end)

  it('highlights footer helpers from the first character', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')
    local ns = vim.api.nvim_get_namespaces()['cosmic-ui-rename-panel']

    ui.open({
      default_value = 'next_name',
    })

    local buf = vim.api.nvim_get_current_buf()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local marks = collect_highlights(buf, ns)
    local footer_marks = {}

    assert.are.equal(' Enter:rename  Esc:cancel ', lines[#lines])

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
        end_col = 6,
        hl_group = 'CosmicUiPanelHintKey',
      },
      {
        lnum = #lines - 1,
        col = 7,
        end_col = 13,
        hl_group = 'CosmicUiPanelHintText',
      },
      {
        lnum = #lines - 1,
        col = 15,
        end_col = 18,
        hl_group = 'CosmicUiPanelHintKey',
      },
      {
        lnum = #lines - 1,
        col = 19,
        end_col = 25,
        hl_group = 'CosmicUiPanelHintText',
      },
    }, footer_marks)
  end)

  it('rejects empty submit from the panel without dispatching rename', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')
    local submissions = 0

    ui.open({
      default_value = '',
      on_submit = function()
        submissions = submissions + 1
      end,
    })

    press('<CR>')
    vim.wait(1000, function()
      local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
      return vim.tbl_contains(lines, ' Name cannot be empty ')
    end)

    assert.are.equal(0, submissions)
    assert.is_true(vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= '')
    assert.is_true(
      vim.tbl_contains(
        vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false),
        ' Name cannot be empty '
      )
    )
  end)

  it('rejects unchanged submit from the panel without dispatching rename', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')
    local submissions = 0

    ui.open({
      default_value = 'current_name',
      on_submit = function()
        submissions = submissions + 1
      end,
    })

    press('<CR>')
    vim.wait(1000, function()
      local lines = vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false)
      return vim.tbl_contains(lines, ' Name is unchanged ')
    end)

    assert.are.equal(0, submissions)
    assert.is_true(vim.api.nvim_win_get_config(vim.api.nvim_get_current_win()).relative ~= '')
    assert.is_true(
      vim.tbl_contains(vim.api.nvim_buf_get_lines(vim.api.nvim_get_current_buf(), 0, -1, false), ' Name is unchanged ')
    )
  end)

  it('restores focus to the origin window on cancel', function()
    stub_rename_context('current_name')

    local ui = require('cosmic-ui.rename.ui')
    local origin_win = vim.api.nvim_get_current_win()

    vim.cmd('split')
    vim.api.nvim_set_current_win(origin_win)

    ui.open({
      default_value = 'next_name',
      on_submit = function()
        error('rename should not submit on cancel')
      end,
    })

    press('<Esc>')
    vim.wait(1000, function()
      return vim.api.nvim_get_current_win() == origin_win
    end)

    assert.are.equal(origin_win, vim.api.nvim_get_current_win())
  end)
end)
