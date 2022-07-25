local m = {}

local config = require('ifactor.config')
local Instance = require('ifactor.instance')
local utils = require('ifactor.utils')

m.ACTIVE_INSTANCE = nil

function m.setup(opts)
  opts = opts or {}
  config.set(opts)
end

local try_initialize, resolve_globs, resolve_transform

--- @param globs string[]
--- @param transform string|IFactorTransform
--- @param opts table<string, any>
function m.start(globs, transform, opts)
  if m.ACTIVE_INSTANCE ~= nil and not m.ACTIVE_INSTANCE.finished then
    utils.printf("Cannot launch new ifactor instance-- one is already running.")
    utils.printf("Clean up existing instance with `ifactor.stop()` before launching new instance.")
  else
    globs = type(globs) == 'string' and resolve_globs(globs) or globs
    transform = type(transform) == 'string' and resolve_transform(transform) or transform
    m.ACTIVE_INSTANCE = Instance:new(globs, transform, opts)
    local ok = try_initialize(m.ACTIVE_INSTANCE)
    if ok then
      m.ACTIVE_INSTANCE:step()
    else
      m.ACTIVE_INSTANCE:destroy()
    end
  end
end

--- Try to iniitialize an `IFactorInstance`. If successful, return `true`. If unsuccessful (an error
---  occurred), print the error message and return `false`.
---
--- @param instance IFactorInstance
--- @return boolean
function try_initialize(instance)
  local success, err = pcall(instance.initialize, instance)
  if not success then
    local base_msg = "An error occurred during initiialization of ifactor instance."
    print(err)
    local msg = utils.stack_error_messages(base_msg, err)
    print(msg)
    return false
  else
    return true
  end
end

--- Look up an ifactor transform by name. The name of the transform is a dot-separated relative
--- module path that will be required relative to `ifactor.transforms`.
---
--- @param name string
--- @return IFactorTransform
function resolve_transform(name)
  local module_path = string.format('ifactor.transforms.%s', name)
  local ok, result = pcall(require, module_path)
  if not ok then
    local msg_temp = "No transform named '%s' found. Make sure `require('ifactor.transforms.%s') " ..
      "returns your transform."
    error(string.format(msg_temp, name, name))
  end
  return result
end

--- Resolve a glob alias to a set of globs by looking it up in the configured
--  `glob_aliases` table.
---
--- @param alias string
--- @return string[]
function resolve_globs(alias)
  local globs = config.glob_aliases[alias]
  if globs == nil then
    error(string.format("Could not resolve glob alias '%s'. Make sure it is present in the `glob_aliase` table."))
  end
  return globs
end

--- Stop and destroy the active IFactor instance (if it exists).
--- @return nil
function m.stop()
  if m.ACTIVE_INSTANCE == nil then
    utils.printf("Cannot stop-- no ifactor instance is running.")
  else
    m.ACTIVE_INSTANCE:destroy()
    m.ACTIVE_INSTANCE = nil
    utils.printf("Stopped ifactor instance.")
  end
end

--- Accept a changeset for the current IFactor instance.
--- @return nil
function m.accept()
  m.ACTIVE_INSTANCE:accept()
end

--- Quit the current IFactor instance.
--- @return nil
function m.quit()
  m.ACTIVE_INSTANCE:quit()
end

--- Reject a changeset for the current IFactor instance.
--- @return nil
function m.reject()
  m.ACTIVE_INSTANCE:reject()
end

--- @param snapshot_id string
function m.restore(snapshot_id)
  if snapshot_id ~= 'pre' and snapshot_id ~= 'post' then
    error("Invalid snapshot id. Must be 'pre' or 'post'.")
  end
  m.ACTIVE_INSTANCE:restore(snapshot_id)
end

--- Resume processingffor the current IFactor instance.
function m.resume()
  m.ACTIVE_INSTANCE:resume()
end

-- ########################
-- ##### TEST
-- ########################

-- --- @param transform string
-- --- @param test_dir string
-- function m.test(transform, test_dir)
--   local _transform = resolve_transform(transform)
--   local inputs = vim.fn.glob(
-- end

return m
