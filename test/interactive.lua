-- This is a script used to itnteractively test ifactor. It must be run from
-- the ifactor project root.

local ifactor = require('ifactor')
local utils = require('ifactor.utils')

local test_code_root = 'test_code'

if vim.fn.isdirectory(test_code_root) == 0 then
  print('test_code directory not found; script must be run from ifactor project root')
  return
end

ifactor.setup()

local QUERY = [[
  (function_definition
    (identifier) @funcname
    (parameters))
]]

-- indexes 0-based
-- TextEdit: {
--   range: {
--     start: { line: rs, character: cs },
--     end: { line: re, character: ce },
--   },
--   newText: str,
-- }


-- prefix any discovered functions
local transform = utils.make_treesitter_query_transform(QUERY, 'python', function (buf, caps)
  local replacement_text = 'foo_' .. vim.treesitter.query.get_node_text(caps.funcname, buf)
  return {
    utils.get_diff_replace_node(caps.funcname, replacement_text)
  }
end)

ifactor.start(
  string.format('%s/**/*.py', test_code_root),
  transform,
  { dry_run = true }
)
