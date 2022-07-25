--- @alias IFactorRawTransform { language: string, query: IFactorRawQuery, diff_fn: IFactorDiffFunction }
--- @alias IFactorTransform { language: string, query: IFactorQuery, diff_fn: IFactorDiffFunction }

--- @alias IFactorRawQuery IFactorRawQueryUnit | IFactorQueryUnit | (IFactorRawQueryUnit|IFactorQueryUnit)[]
--- @alias IFactorRawQueryUnit string | { ts_query: string, filter_fn?: IFactorFilterFunction }

--- @alias IFactorQuery IFactorQueryUnit[]
--- @alias IFactorQueryUnit{ ts_query: string, filter_fn?: IFactorFilterFunction, bindings_fn?: IFactorBindingsFunction }
--- @alias IFactorCompiledQueryUnit { ts_query: TSQuery, filter_fn?: IFactorFilterFunction, bindings_fn?: IFactorBindingsFunction }

--- @alias IFactorBindings table<string, string>

--- @alias IFactorDiffFunction fun(buf:number, match: IFactorQueryMatch): IFactorDiff
--- @alias IFactorFilterFunction fun(buf: number, match: IFactorQueryMatch): boolean
--- @alias IFactorBindingsFunction fun(buf: number, match: IFactorQueryMatch): IFactorBindings

--- @alias IFactorQueryMatch table<string, TSNode>
--- @alias LspPosition { line: number, character: number }  # 0-indexed
--- @alias LspRange { start: LspPosition, end: LspPosition }
--- @alias LspTextEdit { range: LspRange, text: string }
--- @alias IFactorRawInstanceOpts { mappings: table<string, string>|nil, cwd: string|nil }
--- @alias IFactorInstanceOpts { mappings: table<string, string>, cwd: string }
--- @alias IFactorCursor LspPosition
--- @alias IFactorFileStatus "unmodified"|"modified"
--- @alias IFactorDiff LspTextEdit[]
