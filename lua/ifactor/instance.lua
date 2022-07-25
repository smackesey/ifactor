local config = require('ifactor.config')
local utils = require("ifactor.utils")

--- @class IFactorInstance
--- @field private initialized boolean
--- @field public finished boolean
--- @field private globs string[]
--- @field private transform IFactorTransform
--- @field private opts IFactorInstanceOpts
--- @field private files string[]
--- @field private file_statuses table<string, IFactorFileStatus>
--- @field private file_index number
--- @field private cursor IFactorCursor
local Instance = {}
Instance.__index = Instance

Instance.COUNTER = 0

function Instance:get_next_id()
  self.COUNTER = self.COUNTER + 1
  return self.COUNTER
end

-- ****************************************************************************
-- ***** CONSTRUCTION *********************************************************

--- @param globs string|string[]
--- @param transform IFactorTransform
--- @param opts IFactorRawInstanceOpts|nil
function Instance:new(globs, transform, opts)
  self.id = self:get_next_id()
  opts = vim.tbl_deep_extend('force', config.instance, opts or {})
  opts.cwd = opts.cwd == nil and vim.fn.getcwd() or opts.cwd
  local obj = {
    globs = globs,
    transform = transform,
    opts = opts,
    initialized = false,
    finished = false,
  }
  return setmetatable(obj, self)
end

-- ****************************************************************************
-- ***** PUBLIC INTERFACE *****************************************************

function Instance:accept()
  if self.finished then
    print("Cannot accept. Instance is finished.")
  else
    if vim.api.nvim_buf_get_option(self.work_buf, 'modified') then
      self:increment_counter('modify')
      self:notify("Accepted (with modification)", "accept_with_modification")
    else
      self:increment_counter('accept')
      self:notify("Accepted", "accept")
    end
    self:refresh_tracker()
    self:step(true)
  end
end

function Instance:quit()
  self:destroy()
  utils.printf("quit ifactor instance [%d]", self.id)
end

function Instance:reject()
  if self.finished then
    print("Cannot reject. Instance is finished.")
  else
    self:restore('pre')
    self:increment_counter("reject")
    self:refresh_tracker()
    self:notify("Rejected", "reject")
    self:step(false)
  end
end

function Instance:restore(snapshot_id)
  if self.finished then
    print("Cannot restore. Instance is finished.")
  else
    self:restore_snapshot(snapshot_id)
    self:notify("Restored", "neutral")
  end
end

function Instance:resume()
  if self.finished then
    print("Cannot resume. Instance is finished.")
  else
    self:step()
  end
end

-- ****************************************************************************
-- ***** INITIALIZATION *******************************************************

local resolve_globs

--- @return boolean
function Instance:initialize()
  self.files = self:with_instance_cwd(function()
    return resolve_globs(self.globs)
  end)
  self.file_statuses = {}
  self.transform_iterator = utils.make_transform_iterator(self.transform)
  if #self.files == 0 then
    utils.printf("No files found matching globs: %s", table.concat(self.globs, ", "))
    self.initialized = true
    self.finished = true
    return false
  else
    self.file_index = 1
    self.cursor = { line = 0, character = 0 }
    self:create_dummy_buf()
    self:create_keymap_buf()
    self:create_tracker_buf()
    self:create_ui()
    self:setup_file()
    self.initialized = true
    return true
  end
end

--- @param globs string[]
--- @return string[]
function resolve_globs(globs)
  local files = {}
  for _, glob in ipairs(globs) do
    for _, filepath in pairs(vim.fn.glob(glob, true, true)) do
      table.insert(files, filepath)
    end
  end
  return files
end

-- ===== BUFFERS ==============================================================

function Instance:create_dummy_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_name(buf, string.format("ifactor-dummy-%d", self.id))
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  self:apply_buf_keymaps(buf)
  self.dummy_buf = buf
end

-- TODO: Make sure I can still modify with code
function Instance:create_tracker_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "language", 'ifactortracker')
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  self:apply_buf_keymaps(buf)
  self.tracker_buf = buf
end

function Instance:create_keymap_buf()
  local buf = vim.api.nvim_create_buf(false, false)
  local lines = vim.tbl_map(function(k)
    return vim.fn.printf("  %-10s %s", self.opts.mappings[k], k)
  end, vim.tbl_keys(self.opts.mappings))
  table.sort(lines)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  self:apply_buf_keymaps(buf)
  self.keymap_buf = buf
end

-- ===== UI ===================================================================

local setup_window_diff

function Instance:create_ui()
  self.ui = {}
  vim.cmd(string.format("tabedit %s", vim.api.nvim_buf_get_name(self.dummy_buf)))
  self.tab = vim.api.nvim_get_current_tabpage()
  self:init_tracker_win()
  vim.cmd("vsplit")
  self:init_work_win()
  vim.cmd("vsplit")
  self:init_source_win()
  vim.fn.win_gotoid(self.tracker_win)
  vim.cmd("split")
  self:init_notification_win()
  vim.cmd('split')
  self:init_keymap_win()
  vim.api.nvim_win_set_height(self.keymap_win, 5)
  -- notification and keymap wins are 5 lines each, 1 tab line, 3 status lines
  local tracker_height = (vim.api.nvim_get_option("lines") -
      vim.api.nvim_get_option('cmdheight') - (2 * 5) - 3 - 1)
  vim.api.nvim_win_set_height(self.tracker_win, tracker_height)
  vim.fn.win_gotoid(self.work_win)
end

function Instance:init_tracker_win()
  local win = vim.fn.win_getid()
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "signcolumn", 'no')
  vim.api.nvim_win_set_buf(win, self.tracker_buf)
  self.tracker_win = win
end

function Instance:init_work_win()
  local win = vim.fn.win_getid()
  vim.api.nvim_win_set_buf(win, self.dummy_buf)
  self.work_win = win
end

function Instance:init_source_win()
  local win = vim.fn.win_getid()
  vim.api.nvim_win_set_buf(win, self.dummy_buf)
  self.source_win = win
end

function Instance:init_notification_win()
  local win = vim.fn.win_getid()
  vim.api.nvim_win_set_buf(win, self.dummy_buf)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "signcolumn", 'no')
  self.notification_win = win
end

function Instance:init_keymap_win()
  local win = vim.fn.win_getid()
  vim.api.nvim_win_set_buf(0, self.keymap_buf)
  vim.api.nvim_win_set_option(win, "number", false)
  vim.api.nvim_win_set_option(win, "signcolumn", 'no')
  self.keymap_win = win
end

-- ****************************************************************************
-- ***** DESTRUCTION **********************************************************

local win_comparator, is_floating_win, try_delete_buffer, try_delete_window

-- This needs to work even for instances in weird invalid states.
-- - Delete any UI elements
-- - Delete any buffers, except the source_buf if it already existed
function Instance:destroy()

  -- ----- UI
  -- We have to delete any floating windows first, because there is an error if
  -- you delete all non-floating while floating still exist.
  local wins = vim.api.nvim_tabpage_list_wins(self.tab)
  table.sort(wins, win_comparator)
  for _, win in pairs(wins) do
    try_delete_window(win)
  end

  -- ----- BUFFERS
  try_delete_buffer(self.dummy_buf)
  try_delete_buffer(self.tracker_buf)
  try_delete_buffer(self.work_buf)
  if not self.file_was_open then
    try_delete_buffer(self.source_buf)
  end

  -- LUA
  require('ifactor').ACTIVE_INSTANCE = nil
end

function win_comparator(win_a, win_b)
  local a_float, b_float = is_floating_win(win_a), is_floating_win(win_b)
  if a_float and not b_float then return true
  elseif not a_float and b_float then return false
  else return win_a < win_b
  end
end

function is_floating_win(win)
  return vim.api.nvim_win_get_config(win).relative ~= ''
end

function try_delete_buffer(buf)
  if buf ~= nil and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

function try_delete_window(win)
  if win ~= nil and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
end

-- ****************************************************************************
-- ***** STEP *****************************************************************

local get_diff_start_position

function Instance:step(dirty)
  if not self.initialized then
    self:initialize()
  elseif self.finished then
    utils.printf("Cannot step. Instance is finished.")
    return
  end

  if not self:file_loaded() then
    self:setup_file()
  end

  -- diff is a list of LSP TextEdit objects
  self:update_snapshot('pre')
  local ok, cursor_pos_or_err, diff = xpcall(self.transform_iterator, debug.traceback, self.work_buf, self.cursor, dirty)

  if not ok then
    self:restore_snapshot('pre')
    self:handle_error(cursor_pos_or_err)
  elseif diff == nil then
    self:next_file()
  else
    vim.lsp.util.apply_text_edits(diff, self.work_buf, 'utf8')
    self:update_snapshot('post')
    local diff_start_pos = get_diff_start_position(diff)
    vim.api.nvim_win_set_cursor(self.work_win, diff_start_pos)
    vim.api.nvim_win_call(self.work_win, function()
      vim.fn.winrestview({ topline = diff_start_pos[1] })
    end)
    self:enable_lsp_for_buf(self.source_buf)
    self.cursor = cursor_pos_or_err
  end
end

function get_diff_start_position(diff)
  local first_edit = diff[1]
  local line, col = first_edit.range.start.line + 1, first_edit.range.start.character
  return { line, col }
end

function Instance:enable_lsp_for_buf(buf)
  local buf_name = vim.api.nvim_buf_get_name(buf)
  local clients = vim.tbl_filter(function(client)
    -- print('%s == %s', self.opts.cwd, client.config.root_dir)
    return self.opts.cwd == client.config.root_dir and
        vim.tbl_contains(client.config.languages, vim.api.nvim_buf_get_option(buf, 'language'))
  end, vim.lsp.get_active_clients())
  -- printf("Found %d clients", #clients)
  for _, client in ipairs(clients) do
    vim.lsp.buf_attach_client(buf, client.id)
  end
end

function Instance:handle_error(err)
  local msg = utils.stack_error_messages(
    'An error occurred in the transform function.',
    err
  )
  print(msg)
  self:notify("Error. [s] skip file, [any other key] quit.", "error", 0)
  vim.schedule(function()
    local char = vim.fn.nr2char(vim.fn.getchar())
    if char == 's' then
      self:next_file()
    else
      self:quit()
    end
  end)
end

function Instance:next_file()
  self:teardown_file()
  if self:has_next_file() then
    self.file_index = self.file_index + 1
    self:step()
  else
    self:finish()
  end
end

-- ****************************************************************************
-- ***** SETUP FILE ***********************************************************

local load_file

function Instance:setup_file()
  vim.cmd('diffoff!')
  local filepath = self.files[self.file_index]
  self:create_source_buf(filepath)
  vim.api.nvim_win_set_buf(self.source_win, self.source_buf)
  vim.api.nvim_win_call(self.source_win, function() setup_window_diff(self.source_win) end)
  self:create_work_buf(self.source_buf)
  vim.api.nvim_win_set_buf(self.work_win, self.work_buf)
  vim.api.nvim_win_call(self.work_win, function() setup_window_diff(self.work_win) end)
  self:reset_ledger()
  self.file_statuses[self.file_index] = 'unmodified'
  self:refresh_tracker()
end

function setup_window_diff(win)
  vim.cmd('diffthis')
  vim.api.nvim_win_set_option(win, "scrollbind", true)
  vim.api.nvim_win_set_option(win, "cursorbind", true)
  vim.api.nvim_win_set_option(win, "foldmethod", 'manual')
  vim.api.nvim_win_set_option(win, "foldenable", false)
end

function Instance:create_source_buf(filepath)
  local buf
  if vim.fn.bufexists(filepath) == 1 then
    buf = vim.fn.bufnr(filepath)
    if vim.api.nvim_buf_get_option(buf, "modified") == 1 then
      error(string.format("File %s is open and modified. Save file and then call `ifactor.resume()`.", filepath))
    else
      self.file_was_open = true
    end
  else
    buf = self:with_instance_cwd(function()
      return load_file(filepath)
    end)
    self.file_was_open = false
  end
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  self.source_buf = buf
end

function load_file(filepath)
  local buf = vim.api.nvim_create_buf(false, false)
  local lines = vim.fn.readfile(filepath)
  vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
  vim.api.nvim_buf_set_option(buf, 'buftype', 'nofile') -- prevents LSP from launching
  vim.api.nvim_buf_set_name(buf, filepath)
  vim.api.nvim_buf_set_option(buf, 'modified', false)
  vim.api.nvim_buf_call(buf, function()
    vim.cmd('language detect')
  end)
  return buf
end

function Instance:create_work_buf(source_buf)
  local lines = vim.api.nvim_buf_get_lines(source_buf, 0, -1, false)
  local buf = vim.api.nvim_create_buf(false, false)
  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  local filepath = self:with_instance_cwd(function()
    -- Use bufname() here instead of nvim_buf_get_name so we can get relative path
    return vim.fn.bufname(source_buf)
  end)
  vim.api.nvim_buf_set_name(buf, string.format('ifactor://%s', filepath))
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'language', vim.api.nvim_buf_get_option(source_buf, 'language'))
  self:apply_buf_keymaps(buf)
  self.work_buf = buf
end

function Instance:reset_ledger()
  self.ledger = { accept = 0, modify = 0, reject = 0 }
end

-- ****************************************************************************
-- ***** TEARDOWN FILE ********************************************************

function Instance:teardown_file()
  if self:file_has_changes() and not self.opts.dry_run then
    self:save_changes()
    self.file_statuses[self.file_index] = 'modified'
  end
  vim.api.nvim_win_set_buf(self.work_win, self.dummy_buf)
  vim.api.nvim_win_set_buf(self.source_win, self.dummy_buf)
  vim.api.nvim_buf_delete(self.work_buf, { force = self.opts.dry_run })
  if not self.file_was_open then
    vim.api.nvim_buf_delete(self.source_buf, {})
  end
  self.snapshot_pre = nil
  self.snapshot_post = nil
  self.ledger = nil
  self.work_buf = nil
  self.source_buf = nil
  self.file_was_open = nil
end

function Instance:save_changes()
  local lines = vim.api.nvim_buf_get_lines(self.work_buf, 0, -1, false)
  vim.api.nvim_buf_set_option(self.source_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(self.source_buf, 0, -1, false, lines)
  if self.file_was_open then
    vim.api.nvim_buf_call(self.source_buf, function()
      vim.cmd("update")
    end)
  else
    self:with_instance_cwd(function()
      vim.fn.writefile(lines, self.files[self.file_index])
    end)
  end
end

-- ****************************************************************************
-- ***** FINISH ***************************************************************

function Instance:finish()
  self:notify("Finished. Press any key to exit.", "finished", 0)
  vim.schedule(function()
    vim.fn.getchar()
    self:destroy()
  end)
end

-- **************************************************************************
-- ***** * SNAPSHOT *********************************************************

function Instance:update_snapshot(id)
  local lines = vim.api.nvim_buf_get_lines(self.work_buf, 0, -1, false)
  if id == 'pre' then
    self.snapshot_pre = lines
  elseif id == 'post' then
    self.snapshot_post = lines
  end
end

function Instance:restore_snapshot(id)
  local lines
  if id == 'pre' then
    lines = self.snapshot_pre
  elseif id == 'post' then
    lines = self.snapshot_post
  end
  vim.api.nvim_buf_set_lines(self.work_buf, 0, -1, false, lines)
end

-- ****************************************************************************
-- ***** STATE ****************************************************************

function Instance:file_loaded()
  return self.source_buf ~= nil
end

function Instance:file_has_changes()
  return self.ledger.accept > 0 or self.ledger.modify > 0
end

function Instance:has_next_file()
  return self.file_index < #self.files
end

-- ****************************************************************************
-- ***** FEEDBACK *************************************************************

function Instance:notify(msg, style, time)
  time = time ~= 0 and (time or 1000) or nil -- time == 0 means no timeout
  local win_width = vim.api.nvim_win_get_width(self.notification_win)
  local pos = vim.api.nvim_win_get_position(self.notification_win)
  local win_row, win_col = pos[1], pos[2]
  local popup_width = #msg + 4 -- padding + border
  local line = win_row + 3
  local col = win_col + math.floor(win_width / 2) - math.floor(popup_width / 2)
  vim.fn.win_gotoid(self.notification_win)
  self:clear_active_notification()
  local win = require('plenary.popup').create(msg, {
    enter = false,
    line = line,
    col = col,
    width = #msg,
    border = {},
    highlight = config.highlights[style],
    borderhighlight = config.highlights[style],
    time = time,
    padding = { 0, 2, 0, 2 },
  })
  vim.api.nvim_win_set_option(win, 'diff', false)
  vim.fn.win_gotoid(self.work_win)
  self.notification_popup_win = win
end

function Instance:clear_active_notification()
  if self.notification_popup_win ~= nil and vim.api.nvim_win_is_valid(self.notification_popup_win) then
    vim.api.nvim_win_close(self.notification_popup_win, true)
  end
end

local STATUS_ICONS = {
  unmodified = '•',
  modified = '+',
}

function Instance:refresh_tracker()
  local filepath = self.files[self.file_index]
  local status = self.file_statuses[self.file_index]
  local ledger_str = string.format("(%d/%d/%d)",
    self.ledger.accept, self.ledger.modify, self.ledger.reject)
  local line = string.format("  %s %s %s", STATUS_ICONS[status], ledger_str, filepath)
  local curr_line = vim.api.nvim_buf_get_lines(self.tracker_buf, 0, 1, false)[1]
  local curr_filepath = curr_line and vim.fn.split(curr_line, " ")[3] or filepath
  vim.api.nvim_buf_set_option(self.tracker_buf, "modifiable", true)
  if curr_filepath == filepath then
    vim.api.nvim_buf_set_lines(self.tracker_buf, 0, 1, false, { line })
  else
    vim.api.nvim_buf_set_lines(self.tracker_buf, 0, 1, false, { line, curr_line })
  end
  vim.api.nvim_buf_set_option(self.tracker_buf, "modifiable", false)
end

-- ****************************************************************************
-- ***** OTHER ****************************************************************

function Instance:with_instance_cwd(fn)
  return utils.with_cwd(self.opts.cwd, fn)
end

function Instance:increment_counter(counter)
  self.ledger[counter] = self.ledger[counter] + 1
end

function Instance:apply_buf_keymaps(buf)
  for cmd, lhs in pairs(self.opts.mappings) do
    vim.api.nvim_buf_set_keymap(
      buf,
      "n",
      lhs,
      string.format('<cmd>lua require("ifactor").%s()<CR>', cmd),
      { noremap = true }
    )
  end
end

return Instance
