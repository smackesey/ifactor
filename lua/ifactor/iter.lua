local m = {}

--- @param transform IFactorTransform
--- @return fun(number, IFactorCursor, boolean): IFactorCursor, IFactorDiff
function m.make_multi_buf_iter(transform)

  local curr_buf, curr_buf_iter
  return function(buf, cursor, dirty)
    if curr_buf ~= buf then
      curr_buf = buf
      curr_buf_iter = m.make_buf_iter(buf, transform, 0)
    elseif dirty then
      curr_buf_iter = m.make_buf_iter(buf, transform, cursor.line)
    end

    local match = curr_buf_iter()
    if match == nil then
      return nil
    else
      local row, col, _ = match.root:start()
      return { line = row, character = col }, transform.diff_fn(buf, match)
    end
  end
end

local compile_query_unit, captures_to_match, get_match_root, make_buf_iter_rec, make_buf_unit_iter

--- @param buf number
--- @param transform IFactorTransform
--- @param start_position? LspPosition
--- @return fun(): IFactorQueryMatch|nil
function m.make_buf_iter(buf, transform, start_position)
  start_position = start_position or { line = 0, character = 0 }
  local parser = vim.treesitter.get_parser(buf, transform.language, {})
  local buf_root = parser:parse()[1]:root()
  local query_copy = vim.list_slice(transform.query, 1, #transform.query)
  return make_buf_iter_rec(buf, transform.language, query_copy, buf_root, {}, start_position)
end

local function pp_child_match(cm, buf)
  local _cm = {}
  for k, v in pairs(cm) do
    if vim.tbl_contains({'pname', 'ptype', 'fname', '_cpname', 'root_2'}, k) then
      _cm[k] = vim.treesitter.query.get_node_text(v, buf)
    end
  end
  vim.pretty_print(_cm)
end

--- @param buf number
--- @param language string
--- @param query IFactorQuery
--- @param n_root TSNode
--- @param bindings table<string, string>
--- @param start_position? LspPosition
--- @return fun(): IFactorQueryMatch|nil
function make_buf_iter_rec(buf, language, query, n_root, bindings, start_position)
  local query_unit = table.remove(query, 1)
  local compiled_query_unit = compile_query_unit(query_unit, language, bindings)
  local iter = make_buf_unit_iter(buf, compiled_query_unit, n_root, bindings, start_position)
  if #query == 0 then
    return iter
  else
    local match, match_bindings = iter()
    local child_iter = nil

    local function iter_rec()
      if not match then
        return nil
      elseif child_iter then
        local child_match, child_bindings = child_iter()
        if child_match then
          local child_match_merged = vim.tbl_extend('error', {}, match, child_match)
          local child_bindings_merged = vim.tbl_extend('error', {}, bindings, child_bindings)
          return child_match_merged, child_bindings_merged
        else
          match, match_bindings = iter()
          child_iter = nil
          return iter_rec()
        end
      elseif not child_iter then
        local n_match_root = get_match_root(match, compiled_query_unit)
        local child_query = vim.list_slice(query, 1, #query)
        child_iter = make_buf_iter_rec(buf, language, child_query, n_match_root, match_bindings)
        return iter_rec()
      end
    end

    return iter_rec
  end
end

--- @param query_unit IFactorQueryUnit
--- @param language string
--- @param bindings IFactorBindings
--- @return IFactorCompiledQueryUnit
function compile_query_unit(query_unit, language, bindings)
  local ts_query = string.gsub(query_unit.ts_query, '${([%w_]+)}', function (key)
    return bindings[key]
  end)
  local compiled_ts_query = vim.treesitter.query.parse_query(language, ts_query)
  return {
    ts_query = compiled_ts_query,
    filter_fn = query_unit.filter_fn,
    bindings_fn = query_unit.bindings_fn,
  }
end

--- @param match IFactorQueryMatch
--- @param compiled_query_unit IFactorCompiledQueryUnit
--- @return TSNode
function get_match_root(match, compiled_query_unit)
  local ts = compiled_query_unit.ts_query
  local key = ts.captures[#ts.captures]
  return match[key]
end

--- @param buf number
--- @param compiled_query_unit IFactorCompiledQueryUnit
--- @param n_root TSNode
--- @param bindings IFactorBindings
--- @param start_position? LspPosition
--- @return fun(): IFactorQueryMatch | nil, IFactorBindings
function make_buf_unit_iter(buf, compiled_query_unit, n_root, bindings, start_position)
  local ts_iter = compiled_query_unit.ts_query:iter_matches(n_root, buf)
  local filter_fn = compiled_query_unit.filter_fn
  local bindings_fn = compiled_query_unit.bindings_fn
  return function()
    while true do
      local _, captures, _ = ts_iter()
      if captures then
        local match = captures_to_match(compiled_query_unit, captures)
        if filter_fn == nil or filter_fn(buf, match) then
          local match_bindings = bindings_fn and
            vim.tbl_extend('error', bindings_fn(buf, match), bindings) or
            bindings
          return match, match_bindings
        end
      else
        return nil
      end
    end
  end
end

--- Convert the user-unfriendly yield of `TSQuery:iter_matches`, a map of capture _indexes_ to nodes,
--- to a map of capture _names_ to nodes.
---
--- @param compiled_query_unit IFactorCompiledQueryUnit
--- @param captures table<number, TSNode>
--- @return IFactorQueryMatch
function captures_to_match(compiled_query_unit, captures)
  local t = {}
  local capture_names = compiled_query_unit.ts_query.captures
  for id, node in pairs(captures) do
    t[capture_names[id]] = node
  end
  return t
end

return m
