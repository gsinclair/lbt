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
    if value then return value end
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
    refer   = details.refer,       -- only present for VSPACE*, SECTION*, ...
    fn      = details.fn,          -- the rest are NOT present for starred commands
    posargs = details.posargs,
    opargs  = details.opargs,
    kwargs  = details.kwargs,
  }
  setmetatable(o, CommandSpec.mt)
  return o
end

lbt.core.CommandSpec = CommandSpec
-- }}}

