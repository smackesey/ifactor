local ts_utils = require('nvim-treesitter.ts_utils')

local if_iter = require('ifactor.iter')

local m = {}

-- ****************************************************************************
-- ***** DEV ******************************************************************

-- local reload_root = '/Users/smackesey/stm/code/elementl/dagster'
local reload_root = '/Users/smackesey/stm/code/elementl/internal'

-- local reload_transform = 'ifactor.transforms.binary_open_with_encoding'
-- local reload_transform = 'ifactor.transforms.dagster_function_type_annotations'
-- local reload_transform = 'ifactor.transforms.dagster_namedtuple_type_annotations'
-- local reload_transform = 'ifactor.transforms.missing_optional_annotations'
-- local reload_transform = 'ifactor.transforms.raise_missing_from'
-- local reload_transform = 'ifactor.transforms.sequence_mapping_check_mismatch'
local reload_transform = 'ifactor.transforms.with_statement_no_encoding'

local reload_glob = '**/*.py'
-- local reload_glob = 'examples/**/*.py'
-- local reload_glob = 'python_modules/dagster/dagster/core/definitions/decorators/op.py'
-- local reload_glob = 'python_modules/dagster/dagster/core/definitions/repository_definition.py'
-- local reload_glob = 'python_modules/dagster/dagster/_utils/test/__init__.py'
-- local reload_glob = 'python_modules/libraries/dagstermill/dagstermill/**/*.py'

function m.reload()
  require("plenary.reload").reload_module('ifactor.utils')
  require("plenary.reload").reload_module('utils.dagster')
  require("plenary.reload").reload_module('ifactor')
  require("plenary.reload").reload_module(reload_transform)
  require('ifactor').setup()

  require('ifactor').start(
    reload_glob,
    require(reload_transform),
    { cwd = reload_root }
  )
end

-- ****************************************************************************
-- ***** DEBUGGING AND LOGGING ************************************************

function m.inspect_instance()
  print(vim.inspect(require('ifactor').ACTIVE_INSTANCE))
end

function m.errorf(template, ...)
  error(string.format(template, ...))
end

function m.printf(template, ...)
  print(string.format(template, ...))
end

--- Return a string that nests `inner_msg` one indentation level under `outer_msg`.
---
--- @param outer_msg string
--- @param inner_msg string
function m.stack_error_messages(outer_msg, inner_msg)
  local indented = vim.tbl_map(function(ln)
    return string.format('  %s', ln)
  end, vim.fn.split(inner_msg, '\n'))
  return string.format('%s\n%s', outer_msg, table.concat(indented, '\n'))
end

-- ****************************************************************************
-- ***** STRING/TABLE *********************************************************

function m.copy(t)
  return vim.list_slice(t, 1, #t)
end

--- Trim a multiline string by removing (a) the longest common indentation from
--  all lines; (b) any leading or trailing empty lines. If `trailing_newline`
--  is true (default), terminate the final line with a newline.

--- Use a vim regexp to slice a region of `str`. Note that this does not
---  support returning capture groups, only the whole match.
--- @param str string
--- @param regex string 
--- @return string | nil
function m.vim_match(str, regex)
  local start, end_ = vim.regex(regex):match_str(str)
  return start and string.sub(str, start, end_) or nil
end

--- @param str string
--- @param trailing_newline? boolean
--- @return string
function m.trim(str, trailing_newline)
  if trailing_newline == nil then
    trailing_newline = true
  end
  local lines = vim.split(str, "\n")
  local indents = vim.tbl_map(function(ln) return #string.match(ln, '^ *') end, lines)
  local min_indent = math.min(unpack(indents))
  lines = vim.tbl_map(function(ln) return string.sub(ln, 1 + min_indent) end, lines)
  local start_index = 1
  while lines[start_index] == '' do
    start_index = start_index + 1
  end
  local end_index = #lines
  while lines[end_index] == '' do
    end_index = end_index - 1
  end
  local joined = table.concat(vim.list_slice(lines, start_index, end_index), "\n")
  return trailing_newline and joined .. "\n" or joined
end

-- ****************************************************************************
-- ***** CONTEXT MANAGERS *****************************************************

--- Execute a function with the working directory temporarily set to a passed value.
---
--- @param cwd string
--- @param fn fun(...): any
--- @return any
function m.with_cwd(cwd, fn)
  local curr_cwd = vim.fn.getcwd()
  vim.cmd(string.format('cd %s', cwd))
  local result = fn()
  vim.cmd(string.format('cd %s', curr_cwd))
  return result
end

--- Execute a function against a temporary buffer that will be torn down after the function
--  executes. Function must take the buffer handle as its only argument. Returns the value returned
--  by the function. Buffer will still be closed if an error occurs.
---
--- @param content string
--- @param fn fun(buf, ...): any
--- @return any
function m.with_temp_buf(content, fn)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, 0, false, vim.fn.split(content, "\n", false))
  local success, result = xpcall(fn, debug.traceback, buf)
  vim.api.nvim_buf_delete(buf, {})
  if success then
    return result
  else
    local msg = m.stack_error_messages("An error occurred inside the function:", result)
    error(msg)
  end
end

-- ****************************************************************************
-- ***** TEST *****************************************************************

-- NOTE: These should only called in a busted/plenary-test context, `assert` needs
-- to be globally available.

function m.test_transform(transform, input, output)
  -- remove common indentation and normalize final newline
  local t_input, t_output = m.trim(input), m.trim(output)
  local result = m.apply_transform_to_string(transform, t_input)
  assert.are.equal(t_output, result)
end

--- Apply transform to a string in automatic mode. Useful for testing transform functions.
---
--- @param raw_transform IFactorRawTransform
--- @param input string
--- @return string
function m.apply_transform_to_string(raw_transform, input)
  local transform = m.normalize_transform(raw_transform)
  return m.with_temp_buf(input, function(buf)
    local master_diff = {}
    for match in if_iter.make_buf_iter(buf, transform) do
      local diff = transform.diff_fn(buf, match)
      vim.list_extend(master_diff, diff)
    end
    vim.lsp.util.apply_text_edits(master_diff, buf, 'utf-8')
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return table.concat(lines, "\n")
  end)
end

-- ****************************************************************************
-- ***** NORMALIZATION ********************************************************

local normalize_query, normalize_query_unit

local VALID_TRANSFORM_KEYS = { 'language', 'query', 'diff_fn' }

--- @param transform IFactorRawTransform
--- @return IFactorTransform
function m.normalize_transform(transform)
  if not
      (type(transform.language) == 'string' and vim.treesitter.language.require_language(transform.language, nil, true)) then
    m.errorf('Language "%s" is not defined.', transform.language)
  elseif transform.diff_fn == nil then
    error('No diff function provided.')
  else
    for k, _ in pairs(transform) do
      if not vim.tbl_contains(VALID_TRANSFORM_KEYS, k) then
        m.errorf('Invalid key "%s" found in transform.', k)
      end
    end
    return {
      language = transform.language,
      query = normalize_query(transform.query, transform.language),
      diff_fn = transform.diff_fn,
    }
  end
end

--- @param raw_query IFactorRawQuery
--- @param language string
--- @return IFactorQuery
function normalize_query(raw_query, language)
  if type(raw_query) == 'string' then
    return { normalize_query_unit(raw_query, language) }
  elseif type(raw_query) == 'table' and not vim.tbl_islist(raw_query) then
    return { normalize_query_unit(raw_query, language) }
  else -- list
    return vim.tbl_map(function(unit)
      return normalize_query_unit(unit, language)
    end, raw_query)
  end
end

--- @param raw_query_unit IFactorRawQueryUnit
--- @param language string
--- @return IFactorQueryUnit
function normalize_query_unit(raw_query_unit, language)
  local unit = raw_query_unit
  if type(unit) == 'string' then
    return { ts_query = unit, filter_fn = nil, bindings_fn = nil }
  elseif type(unit) == 'table' and type(unit.ts_query) == 'string' then
    return unit
  else
    error('Invalid query.')
  end
end

-- ****************************************************************************
-- ***** DIFF *****************************************************************

m.diff = {}

--- @param node TSNode
--- @param new_text string
--- @return LspTextEdit
function m.diff.replace_node(node, new_text)
  return { range = ts_utils.node_to_lsp_range(node), newText = new_text }
end

function m.diff.insert_before_node(node, new_text)
  local node_range = ts_utils.node_to_lsp_range(node)
  return {
    range = {
      start = node_range['start'],
      ['end'] = node_range['start'],
    },
    newText = new_text
  }
end

--- @param node TSNode
--- @param new_text string
--- @return LspTextEdit
function m.diff.insert_after_node(node, new_text)
  local node_range = ts_utils.node_to_lsp_range(node)
  return {
    range = {
      start = node_range['end'],
      ['end'] = node_range['end'],
    },
    newText = new_text
  }
end

return m
