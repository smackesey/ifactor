local m = {}

local config = require('ifactor.config')
local Instance = require('ifactor.instance')
local utils = require('ifactor.utils')

m.ACTIVE_INSTANCE = nil

function m.setup(opts)
  opts = opts or {}
  config.set(opts)
end

local try_initialize, resolve_transform

function m.start(globs, transform, opts)
  if m.ACTIVE_INSTANCE ~= nil and not m.ACTIVE_INSTANCE.finished then
    utils.printf("Cannot launch new ifactor instance-- one is already running.")
    utils.printf("Clean up existing instance with `ifactor.stop()` before launching new instance.")
  else
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

function try_initialize(instance)
  local success, err = pcall(m.ACTIVE_INSTANCE.initialize, m.ACTIVE_INSTANCE)
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

function resolve_transform(name)
  local module_path = string.format('ifactor.transforms.%s', name)
  local ok, result = pcall(require, module_path)
  if not ok then
    local msg_temp = "No transform named '%s' found. Make sure `require('ifactor.transforms.%s') " ..
      "returns your transform function."
    error(string.format(msg_temp, name, name))
  end
  return result
end

function m.stop(globs, transform, opts)
  if m.ACTIVE_INSTANCE == nil then
    utils.printf("Cannot stop-- no ifactor instance is running.")
  else
    m.ACTIVE_INSTANCE:destroy()
    m.ACTIVE_INSTANCE = nil
    utils.printf("Stopped ifactor instance.")
  end
end


function m.accept()
  m.ACTIVE_INSTANCE:accept()
end

function m.quit()
  m.ACTIVE_INSTANCE:quit()
end

function m.reject()
  m.ACTIVE_INSTANCE:reject()
end

function m.restore()
  m.ACTIVE_INSTANCE:restore()
end

function m.resume()
  m.ACTIVE_INSTANCE:resume()
end

return m
