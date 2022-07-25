--- Stub class. Up-to-date method list here:
---   https://neovim.io/doc/user/treesitter.html
--- @class TSQuery
--- @field captures string[]  # list of capture names
local TSQuery = {}

--- @param node TSNode
--- @param source number  # buffer number
--- @param start? number  # start row
--- @param stop? TSNode  # end row
--- @return fun(): number, TSNode, table<any, any>
---   capture id, capture node, match metadata
function TSQuery:iter_captures(node, source, start, stop) end

--- @param node TSNode
--- @param source number  # buffer number
--- @param start? number  # start row
--- @param stop? TSNode  # end row
--- @return fun(): number, TSNode, table<number, TSNode>
---   pattern index, capture index-to-node map, match metadata
function TSQuery:iter_matches(node, source, start, stop) end

return TSQuery
