local m = {}

-- ****************************************************************************
-- ***** DEBUGGING AND LOGGING ************************************************

function m.inspect_instance()
  print(vim.inspect(require('ifactor').ACTIVE_INSTANCE))
end

function m.printf(template, ...)
  print(string.format(template, ...))
end

function m.reload()
  require("plenary.reload").reload_module('ifactor')
  require("plenary.reload").reload_module('ifactor.transforms.dagster_type_annotations')
  require('ifactor').setup()
  -- local test_script = 'test/interactive.lua'
  -- vim.cmd(string.format('source %s', test_script))

  require('ifactor').start(
    'python_modules/**/*.py',
    require('ifactor.transforms.dagster_type_annotations'),
    { cwd = '/Users/smackesey/stm/code/elementl/dagster' }
  )
end

function m.stack_error_messages(outer_msg, inner_msg)
  local indented = vim.tbl_map(function (ln)
    return string.format('  %s', ln)
  end, vim.fn.split(inner_msg, '\n'))
  return string.format('%s\n%s', outer_msg, table.concat(indented, '\n'))
end

-- ****************************************************************************
-- ***** LSP / TREESITTER *****************************************************

function m.lsp_range_for_node(node)
  local rs, cs, re, ce = node:range()
  return {
    start = {line = rs, character = cs},
    ["end"] = {line = re, character = ce},
  }
end

function m.get_diff_replace_node(node, new_text)
  return { range = m.lsp_range_for_node(node), newText = new_text }
end

local make_buffer_iter, make_capture_table

function m.make_treesitter_query_transform(query_str, filetype, transform_fn)
  local query = vim.treesitter.parse_query(filetype, query_str)
  assert(query, 'Could not parse treesitter query.')

  local curr_buf, curr_buf_iter
  return function(buf, cursor)
    if curr_buf ~= buf then
      curr_buf = buf
      curr_buf_iter = make_buffer_iter(buf, query)
    end
    local _, captures, _ = curr_buf_iter()
    if captures then
      local capture_table = make_capture_table(query, captures)
      return transform_fn(buf, capture_table)
    else
      return nil
    end
  end
end

function make_buffer_iter(buf, query)
  -- local ft = vim.api.nvim_buf_get_option(buf, 'filetype')
  local ft = 'python'  -- temporary
  local parser = vim.treesitter.get_parser(buf, ft, {})
  local node = parser:parse()[1]:root()
  return query:iter_matches(node, 0, 0, 0)
end

function make_capture_table(query, captures)
  local t = {}
  for id, node in pairs(captures) do
    t[query.captures[id]] = node
  end
  return t
end

return m 
