describe('cosmic-ui.rename.handler', function()
  local original_apply_workspace_edit
  local original_expand
  local original_get_clients
  local original_notify
  local applied
  local notifications

  before_each(function()
    original_apply_workspace_edit = vim.lsp.util.apply_workspace_edit
    original_expand = vim.fn.expand
    original_get_clients = vim.lsp.get_clients
    original_notify = vim.notify
    applied = {}
    notifications = {}

    vim.lsp.util.apply_workspace_edit = function(edit, offset_encoding)
      table.insert(applied, {
        edit = edit,
        offset_encoding = offset_encoding,
      })
    end

    vim.fn.expand = function(expr)
      if expr == '<cword>' then
        return 'old_name'
      end

      return original_expand(expr)
    end

    vim.notify = function(message, level, opts)
      table.insert(notifications, {
        message = message,
        level = level,
        opts = opts,
      })
    end
  end)

  after_each(function()
    vim.lsp.util.apply_workspace_edit = original_apply_workspace_edit
    vim.fn.expand = original_expand
    vim.lsp.get_clients = original_get_clients
    vim.notify = original_notify
  end)

  it('reports rename errors without applying a workspace edit', function()
    local handler = require('cosmic-ui.rename.handler')

    handler({ message = 'rename failed' }, nil, {
      method = 'textDocument/rename',
    })

    assert.are.equal(0, #applied)
    assert.are.equal(1, #notifications)
    assert.are.equal(vim.log.levels.ERROR, notifications[1].level)
    assert.are.equal("Error running LSP query 'textDocument/rename': rename failed", notifications[1].message)
  end)

  it('logs change summaries and applies edits with the responding client encoding', function()
    local handler = require('cosmic-ui.rename.handler')
    local uri = vim.uri_from_fname(vim.fs.joinpath(vim.fn.getcwd(), 'sample.lua'))
    local result = {
      changes = {
        [uri] = {
          {
            range = {
              start = { line = 0, character = 0 },
              ['end'] = { line = 0, character = 8 },
            },
            newText = 'new_name',
          },
          {
            range = {
              start = { line = 1, character = 0 },
              ['end'] = { line = 1, character = 8 },
            },
            newText = 'new_name',
          },
        },
      },
    }

    vim.lsp.get_clients = function(filter)
      assert.are.same({ id = 7 }, filter)
      return { { id = 7, offset_encoding = 'utf-8' } }
    end

    handler(nil, result, {
      client_id = 7,
      method = 'textDocument/rename',
    })

    assert.are.same({
      {
        edit = result,
        offset_encoding = 'utf-8',
      },
    }, applied)
    assert.are.equal(1, #notifications)
    assert.are.equal(vim.log.levels.INFO, notifications[1].level)
    assert.are.equal('2 changes -> ./sample.lua', notifications[1].message)
    assert.are.equal('Rename: old_name -> new_name', notifications[1].opts.title)
  end)

  it('passes documentChanges workspace edits through without change summaries', function()
    local handler = require('cosmic-ui.rename.handler')
    local result = {
      documentChanges = {
        {
          textDocument = {
            uri = vim.uri_from_fname(vim.fs.joinpath(vim.fn.getcwd(), 'sample.lua')),
            version = 1,
          },
          edits = {
            {
              range = {
                start = { line = 0, character = 0 },
                ['end'] = { line = 0, character = 8 },
              },
              newText = 'new_name',
            },
          },
        },
      },
    }

    vim.lsp.get_clients = function()
      return { { id = 8, offset_encoding = 'utf-16' } }
    end

    handler(nil, result, {
      client_id = 8,
      method = 'textDocument/rename',
    })

    assert.are.same({
      {
        edit = result,
        offset_encoding = 'utf-16',
      },
    }, applied)
    assert.are.same({}, notifications)
  end)
end)
