describe('cosmic-ui.utils', function()
  it('formats file URIs as decoded paths relative to the working directory', function()
    local utils = require('cosmic-ui.utils')
    local path = vim.fs.joinpath(vim.fn.getcwd(), 'folder', 'a b.lua')

    assert.are.equal('./folder/a b.lua', utils.get_relative_path(vim.uri_from_fname(path)))
  end)

  it('keeps paths outside the working directory absolute', function()
    local utils = require('cosmic-ui.utils')
    local path = vim.fs.normalize(vim.fn.tempname())

    assert.are.equal(path, utils.get_relative_path(vim.uri_from_fname(path)))
  end)

  it('joins list notifications in order', function()
    local utils = require('cosmic-ui.utils')
    local original_notify = vim.notify
    local notification

    vim.notify = function(message)
      notification = message
    end

    local ok, err = pcall(function()
      utils.Logger:log({ 'first', 'second', 'third' })
    end)
    vim.notify = original_notify

    assert.is_true(ok, err)
    assert.are.equal('first\nsecond\nthird', notification)
  end)
end)
