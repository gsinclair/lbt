--
-- We act on the global table `lbt` and populate its subtable `lbt.core`.
--
-- lbt.core serves to contain foundational classes and functions that could be used
-- anywhere in the implementation code (api, fn-*).
--
-- At the moment, that is:
--  * DictionaryStack for supporting layered lookups (for opargs)
--  * basic functions to do with opargs
--
-- So it's very oparg heavy. That's because the idea of optional arguments cut through
-- the whole document. They can be set at the Latex level, or in an LBT document, or
-- in a command.

local F = string.format

lbt.core = {}
local impl = {}


-- {{{ Pragmas ---------------------------------------------------------------

lbt.core.DefaultPragmas = {
  DRAFT  = false,
  IGNORE = false,
  SKIP   = false,
  DEBUG  = false
}

lbt.core.default_pragmas = function()
  return pl.tablex.copy(lbt.core.DefaultPragmas)
end

lbt.core.default_pragma = function(key)
  local value = lbt.core.DefaultPragmas[key]
  if value == nil then
    lbt.err.E002_general("Attempt to get default for non-existent pragma: '%s'", key)
  end
end

-- }}}

-- {{{ Logging ---------------------------------------------------------------

-- There are two log files:
--  * lbt.log is written to with lbt.log('emit', 'Hello %s', name)
--    * set the active channels with lbt.core.set_log_channels
--  * lbt.debuglog is written to with lbt.debuglog('Hello %s', name)
--    * this doesn't have channels; it is for temporary development and debugging

local logfile = io.open("lbt.log", "w")

local _debuglogfile = nil
local debuglogfile = function()
  if _debuglogfile then
    return _debuglogfile
  else
    _debuglogfile = io.open('lbt.debuglog', 'w')
    return _debuglogfile
  end
end

local channel_name = { [0] = 'ANN',  [1] = 'ERROR', [2] = 'WARN',
                       [3] = 'INFO', [4] = 'TRACE' }

lbt.core.log = function (channel, format, ...)
  if lbt.core.query_log_channels(channel) then
    local message
    if ... == nil then
      message = format
    else
      message = F(format, ...)
    end
    local name = channel_name[channel] or channel
    local line = F('[#%-10s] %s\n', name, message)
    logfile:write(line)
    logfile:flush()
  end
end

lbt.core.debuglog = function(format, ...)
  local line
  if format == nil then
    line = 'nil'
  else
    line = F(format, ...)
  end
  lbt.core.debuglograw(line)
end

lbt.core.debuglograw = function(text)
  local file = debuglogfile()
  file:write(text)
  file:write('\n')
  file:flush()
end

lbt.core.remove_debuglog = function()
  pl.file.delete('lbt.debuglog')
end

lbt.core.set_log_channels = function (text, separator)
  text = tostring(text)
  lbt.system.log_channels = pl.List()
  local channels
  if separator == 'comma' then
    channels = lbt.util.comma_split(text)       -- NOTE: this is temporary
  elseif separator == 'space' then
    channels = lbt.util.space_split(text)
  else
    lbt.err.E002_general("Don't use \\lbtLogChannels anymore; use \\lbtSettings{LogChannels = ...}")
  end
  for c in channels:iter() do
    if c:match('^[1234]$') then
      c = tonumber(c)
    end
    lbt.system.log_channels:append(c)
  end
  lbt.log(0, 'Log channels set to: %s', lbt.system.log_channels)
end

lbt.core.query_log_channels = function (ch)
  local x = lbt.system.log_channels
  if ch == 0 or ch == 1 or ch == 2 or ch == 3 then
    return true
  elseif x:contains('all') then
    return true
  elseif x:contains('allbuttrace') and ch ~= 4 then
    return true
  elseif x:contains(ch) then
    return true
  else
    return false
  end
end

-- }}}

-- {{{ Settings --------------------------------------------------------------

-- \lbtSettings{DraftMode = true, HaltOnWarning = true}
-- \lbtSettings{
--   CurrentContentsLevel = section,
--   LogChannels = 4 emit trace,
-- }
local DefaultSettings = {
  DraftMode = false,
  WriteExpansionFiles = true,
  ClearExpansionFiles = true,
  DebugAllExpansions = false,
  HaltOnWarning = false,
  CurrentContentsLevel = 'section',
    -- TODO: this ^^^ should perhaps be in WS0, WS1, ... rather than a setting,
    -- or maybe named AddToContentsLevel instead
  LogChannels = '1',                   -- TODO: determine suitable default
}

local Settings = {}
Settings.mt = { __index = Settings }   -- XXX: maybe metatable not needed here?

-- Create a Settings object with default values.
function Settings.new()
  local o = {}
  o.dict = pl.tablex.copy(DefaultSettings)
  setmetatable(o, Settings.mt)
  return o
end

function Settings:apply(key, value)
  if DefaultSettings[key] == nil then
    lbt.err.E002_general("Attempt to set invalid setting: '%s'", key)
  else
    self.dict[key] = value
    local errmsg = impl.consider_setting_more_carefully(self.dict, key, value)
    return errmsg
  end
end

function Settings:get(key)
  if DefaultSettings[key] == nil then
    lbt.err.E002_general("Attempt to look up invalid setting: '%s'", key)
  else
    return self.dict[key]
  end
end

lbt.core.Settings = Settings

-- Validate (and return error message if needed) and apply side effects.
function impl.consider_setting_more_carefully(dict, key, value)
  if key == 'LogChannels' then
    lbt.core.set_log_channels(value, 'space')
  elseif key == 'DraftMode' then
    if value then
      lbt.log(3, 'Draft mode is enabled (only content with !DRAFT will be rendered)')
    else
      lbt.log(3, 'Draft mode is disabled (all content will be rendered)')
    end
  end
end

-- }}}

-- {{{ DictionaryStack --------------------------------------------------------------
-- Useful for layers of options.

local DictionaryStack = {}
DictionaryStack.mt = { __index = DictionaryStack }

function DictionaryStack.new()
  local o = {
    type = 'DictionaryStack',
    layers = pl.List()
  }
  setmetatable(o, DictionaryStack.mt)
  return o
end

function DictionaryStack:empty()
  return self.layers:len() == 0
end

function DictionaryStack:push(map)
  self.layers:append(map)
end

function DictionaryStack:pop()
  self.layers:pop()
end

function DictionaryStack:lookup(key)
  for i = self.layers:len(), 1, -1 do
    local layer = self.layers[i]
    local value = layer[key]
    if value ~= nil then return value end
  end
  return nil
end

lbt.core.DictionaryStack = DictionaryStack
-- }}}

-- {{{ Some oparg-related functions -------------------------------------------------
--
-- These are in 'core' so they can be used from anywhere, and to document a core
-- aspect of the system.

function lbt.core.oparg_check_qualified_key(key)
  if type(key) == 'string' and key:match('%.') then
    return nil
  else
    lbt.err.E002_general("qualified key like `MATH.align` required; got '%s'", key)
  end
end

function lbt.core.oparg_split_qualified_key(qkey)
  local bits = lbt.util.split(qkey, '%.')
  if bits:len() == 2 then
    return table.unpack(bits)
  else
    lbt.err.E002_general("qualified key like `MATH.align` required; got '%s'", qkey)
  end
end

function lbt.core.sanitise_oparg_nil(value)
  if value == 'nil' then
    return nil
  else
    return value
  end
end

-- }}}

-- {{{ CommandSpec ------------------------------------------------------------------

local CommandSpec = {}
CommandSpec.mt = { __index = CommandSpec }

function CommandSpec.new(details)
  local o = {
    type    = 'CommandSpec',
    opcode  = details.opcode,
    source  = details.source,
    starred = details.starred,     -- true or false
    refer   = details.refer,       -- only present for VSPACE*, SECTION*, ...
    fn      = details.fn,
    opargs  = details.opargs,
    kwargs  = details.kwargs,
    posargs = details.posargs,
  }
  setmetatable(o, CommandSpec.mt)
  return o
end

lbt.core.CommandSpec = CommandSpec
-- }}}
