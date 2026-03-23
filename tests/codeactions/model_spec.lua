describe('cosmic-ui.codeactions.ui.model', function()
  it('builds grouped headerless rows for available actions', function()
    local model = require('cosmic-ui.codeactions.ui.model')
    local built = model.build({
      [2] = {
        client = { id = 2, name = 'zeta' },
        result = {
          { title = 'Fix trailing spaces' },
        },
      },
      [1] = {
        client = { id = 1, name = 'alpha' },
        result = {
          { title = 'Organize Imports' },
          { title = 'Extract Function' },
        },
      },
    })

    assert.is_nil(built.title)
    assert.is_nil(built.subtitle)
    assert.are.equal(3, #built.actions)
    assert.are.same(
      {
        'section',
        'action',
        'action',
        'section',
        'action',
      },
      vim.tbl_map(function(row)
        return row.kind
      end, built.rows)
    )
    assert.are.equal('alpha', built.rows[1].text)
    assert.are.equal('zeta', built.rows[4].text)
  end)

  it('builds an explicit empty state when no actions are available', function()
    local model = require('cosmic-ui.codeactions.ui.model')
    local built = model.build({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = {},
      },
    })

    assert.are.equal(0, #built.actions)
    assert.is_nil(built.title)
    assert.is_nil(built.subtitle)
    assert.are.same({
      kind = 'state',
      state = 'empty',
      text = 'No code actions available',
    }, built.rows[1])
  end)

  it('keeps successful actions visible when one client errors', function()
    local model = require('cosmic-ui.codeactions.ui.model')
    local built = model.build({
      [1] = {
        client = { id = 1, name = 'lua_ls' },
        result = { { title = 'Organize Imports' } },
      },
      [2] = {
        client = { id = 2, name = 'eslint' },
        error = { code = -1, message = 'request failed' },
        result = nil,
      },
    })

    assert.are.equal(1, #built.actions)
    assert.are.equal(true, built.has_partial_error)
    assert.are.equal(1, built.error_count)
    assert.are.same({
      kind = 'state',
      state = 'warn',
      text = '1 source failed to return code actions',
    }, built.rows[1])
  end)
end)
