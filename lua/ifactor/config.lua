local m = {}

local DEFAULT_CONFIG = {
  instance = {
    dry_run = false,
    mappings = {
      quit = "<F5><F2>",
      reject = "<F5><F3>",
      accept = "<F5><F4>",
      restore_pre = "<F5><F5>",
      restore_post = "<F5><F6>",
    },
  },
  highlights = {
    accept = 'Function',  -- green
    accept_with_modification = 'Identifier',  -- blue
    error = 'Statement',  -- red
    reject = 'Statement',  -- red
    finish = 'Boolean',  -- purple
    restore = 'Boolean',  -- purple
  },
  transform_path = {},
  glob_aliases = {},
}

local meta = {
  set = function(opts)
    local new = vim.tbl_deep_extend('force', DEFAULT_CONFIG, opts)
    for k, v in pairs(new) do
      m[k] = v
    end
    -- Not quite sure why this is required, but it doesn't work without it.
    vim.schedule(function()
      vim.cmd('highlight default link ifactortrackerModifiedStatus ' .. m.highlights.finish)
      vim.cmd('highlight default link ifactortrackerAcceptCount ' .. m.highlights.accept)
      vim.cmd('highlight default link ifactortrackerAcceptWithModificationCount ' .. m.highlights.accept_with_modification)
      vim.cmd('highlight default link ifactortrackerRejectCount ' .. m.highlights.reject)
    end)
  end
}
meta.__index = meta
setmetatable(m, meta)

return m
