describe("cosmic-ui.formatters.ui.rows", function()
  local function find_row(rows, id)
    for _, row in ipairs(rows) do
      if row.id == id then
        return row
      end
    end

    return nil
  end

  it("renders conform-unavailable rows with explanatory text", function()
    local rows = require("cosmic-ui.formatters.ui.rows")
    local built = rows.build_rows({
      conform = { available = false, reason = "conform unavailable", formatters = {}, fallback = {} },
      lsp_clients = {},
    }, { conform = "C", lsp = "L", file = "F", filetype = "lua" }, { unavailable = "!" })

    local row = find_row(built, "conform_unavailable")
    assert.are.same({
      id = "conform_unavailable",
      text = "! C Conform unavailable: conform unavailable",
      toggleable = false,
      kind = "info",
      status = "unavailable",
      status_icon = "!",
      source_icon = "C",
      reason = "conform unavailable",
    }, row)
  end)

  it("renders empty backend rows with explicit source labels", function()
    local rows = require("cosmic-ui.formatters.ui.rows")
    local built = rows.build_rows({
      conform = {
        available = true,
        reason = nil,
        formatters = {},
        fallback = { display_global_mode = "fallback" },
      },
      lsp_clients = {},
    }, { conform = "C", lsp = "L", file = "F", filetype = "lua" }, { unavailable = "!" })

    assert.are.same({
      id = "conform_empty",
      text = "! C Conform: no formatters available",
      toggleable = false,
      kind = "info",
      status = "unavailable",
      status_icon = "!",
      source_icon = "C",
    }, find_row(built, "conform_empty"))

    assert.are.same({
      id = "lsp_empty",
      text = "! L LSP: no attached clients",
      toggleable = false,
      kind = "info",
      status = "unavailable",
      status_icon = "!",
      source_icon = "L",
    }, find_row(built, "lsp_empty"))
  end)

  it("stores shared section metadata separately from section text", function()
    local rows = require("cosmic-ui.formatters.ui.rows")
    local built = rows.build_rows({
      conform = {
        available = true,
        reason = nil,
        formatters = {
          { name = "stylua", enabled = true },
        },
        fallback = {
          display_global_mode = "never",
          display_specific_mode = "fallback",
        },
      },
      lsp_clients = {
        { name = "lua_ls", available = true, enabled = true },
      },
    }, { conform = "C", lsp = "L", file = "F", filetype = "lua" }, {
      enabled = "+",
      disabled = "-",
      unavailable = "!",
    })

    assert.are.same({
      id = "section_conform",
      text = "Conform",
      toggleable = false,
      kind = "section",
    }, find_row(built, "section_conform"))

    assert.are.same({
      id = "section_lsp",
      text = "LSP",
      subtitle = "fallback",
      toggleable = false,
      kind = "section",
    }, find_row(built, "section_lsp"))
  end)
end)
