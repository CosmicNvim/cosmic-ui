local ui = require('cosmic-ui.rename.ui')

local function rename(popup_opts, opts)
  return ui.open(popup_opts, opts)
end

return rename
