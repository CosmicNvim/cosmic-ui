describe('cosmic-ui.codeactions.transform', function()
  it('applies the Java workspace edit command without executing it twice', function()
    local transform = require('cosmic-ui.codeactions.transform')
    local original_apply_workspace_edit = vim.lsp.util.apply_workspace_edit
    local seen = {}
    local edit = {
      documentChanges = {
        {
          textDocument = {
            uri = 'file:///tmp/example.java',
            version = 0,
          },
          edits = {},
        },
      },
    }
    local command = {
      title = 'Apply workspace edit',
      command = 'java.apply.workspaceEdit',
      arguments = { edit },
    }
    local client = {
      offset_encoding = 'utf-16',
      exec_cmd = function()
        error('java.apply.workspaceEdit should not execute after its edit is applied locally')
      end,
    }

    vim.lsp.util.apply_workspace_edit = function(workspace_edit, offset_encoding)
      seen = { workspace_edit = workspace_edit, offset_encoding = offset_encoding }
    end

    local ok, err = pcall(function()
      transform.execute_action(transform.transform_action(command), client, { bufnr = 1 })
    end)

    vim.lsp.util.apply_workspace_edit = original_apply_workspace_edit
    if not ok then
      error(err)
    end

    assert.are.equal(edit, seen.workspace_edit)
    assert.are.equal('utf-16', seen.offset_encoding)
    assert.is_nil(edit.documentChanges[1].textDocument.version)
  end)
end)
