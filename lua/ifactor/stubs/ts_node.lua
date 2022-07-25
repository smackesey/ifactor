--- @class TSNode  # Stub class. Up-to-date method list here:
---   https://neovim.io/doc/user/treesitter.html
local TSNode = {}

--- @return TSNode|nil
function TSNode:parent()  end

--- @return TSNode|nil
function TSNode:next_sibling()  end

--- @return TSNode|nil
function TSNode:prev_sibling()  end

--- @return TSNode|nil
function TSNode:next_named_sibling()  end

--- @return TSNode|nil
function TSNode:prev_named_sibling()  end

--- @return fun():TSNode|nil, string|nil
function TSNode:iter_children()  end

--- @param name string
--- @return TSNode|nil
function TSNode:field(name)  end

--- @return number
function TSNode:child_count()  end

--- @param index number
--- @return TSNode|nil
function TSNode:child(index)  end

--- @return number
function TSNode:named_child_count()  end

--- @param index number
--- @return TSNode|nil
function TSNode:named_child(index)  end

--- @return number, number, number  # row, column, byte-index
function TSNode:start() end

--- @return number, number, number  # row, column, byte-index
function TSNode:end_() end

--- @return number, number, number, number  # start_row, start_col, end_row, end_col
function TSNode:range() end

--- @return string
function TSNode:type() end

--- @return number
function TSNode:symbol() end

--- @return boolean
function TSNode:named() end

--- @return boolean
function TSNode:missing() end

--- @return boolean
function TSNode:has_error() end

--- @return string
function TSNode:sexpr() end

--- @return string -- note this string is non-printable
function TSNode:id() end

--- @param start_row number
--- @param start_col number
--- @param end_row number
--- @param end_col number
--- @return TSNode|nil
function TSNode:descendant_for_range(start_row, start_col, end_row, end_col) end

--- @param start_row number
--- @param start_col number
--- @param end_row number
--- @param end_col number
--- @return TSNode|nil
function TSNode:named_descendant_for_range(start_row, start_col, end_row, end_col) end

return TSNode
