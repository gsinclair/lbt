-- A Command object lives for the duration of one LBT command.
-- It is used within lbt.fn.latex_for_command. Through this object, we gain access
-- to validation of arguments, opargs and kwargs. Through the provided expansion
-- context, we can resolve opcodes.

local F = string.format

-- But first, we implement OptionLookup, because this is the only place it will be used.
-- (Well, the only place it will be created. It will be called far and wide.)

-- {{{ OptionLookup -----------------------------------------------------------------

local OptionLookup = {}

-- Private keys for our object, so as not to interfere with __index.
local _opcode_     = {}
local _opargs_cmd_ = {}
local _ctx_        = {}


-- Example, where TEXT* was the opcode in the document.
--
--   option_lookup = lbt.fn.OptionLookup.new {
--     opcode = 'TEXT'
--     opargs_cmd = { prespace = '3em' },
--     expansion_context = <ExpansionContext>,
--     starred = true
--   }

function OptionLookup.new(args)
  -- Extract the arguments
  local opcode = args.opcode
  local opargs_cmd = args.opargs_cmd
  local expansion_context = args.expansion_context
  local starred = args.starred
  -- Validate the arguments
  assert(type(opcode) == 'string')
  assert(type(opargs_cmd) == 'table')
  assert(expansion_context.type == 'ExpansionContext')
  assert(starred == true or starred == false or starred == nil)
  -- Create the object and store the data
  local o = {}
  o[_opcode_]     = opcode
  o[_opargs_cmd_] = pl.tablex.copy(opargs_cmd)
  if starred then o[_opargs_cmd_].starred = true end   -- take care of starred opcode
  o[_ctx_]        = expansion_context
  setmetatable(o, OptionLookup)
  -- We need to put explicit methods in so that __index is not triggered.
  o._lookup        = OptionLookup._lookup
  o._has_local_key = OptionLookup._has_local_key
  o._set_local     = OptionLookup._set_local
  o._has_key       = OptionLookup._has_key
  o._safe_index    = OptionLookup._safe_index
  o._extract_multi_values = OptionLookup._extract_multi_values
  o.f              = OptionLookup.f
  return o
end

-- For debugging: get access to fields of the object.
function OptionLookup:f(x)
  if x == 'opargs' or x == 'o' then return self[_opargs_cmd_] end
  if x == 'ctx'                then return self[_ctx_]        end
  if x == 'opcode'             then return self[_opcode_]     end
end

-- Supporting option lookup below.
local qualified_key = function(ol, key)
  if string.find(key, '%.') then
    return key
  elseif ol[_opcode_] then
    return ol[_opcode_] .. '.' .. key
  else
    -- XXX: This should not be necessary. It should be impossible to create an OptionLookup
    -- without an opcode.
    lbt.err.E191_cannot_qualify_key_for_option_lookup(key)
  end
end

-- Doing an option lookup is complex.
--  * First of all, the key is probably a simple one ('color') and needs to be
--    qualified ('QQ.color').
--  * Then, it might be set as an opcode-local option.
--    However, it is possible to resolve an option without even having an opcode.
--    A template could be rendering a title page, for example. It hasn't even
--    got to BODY yet.
--  * Otherwise, it might be in the cache, from a previous access.
--  * Otherwise, it might be a document-narrow option.
--  * Otherwise, it might be a document-wide option.
--  * Otherwise, it might be a default in a template.
-- If the key cannot be found anywhere, we return nil. A missing option should
-- be an error, but we leave that up to the caller because we want to provide
-- different errors depending on whether the lookup was for a command or for
-- a macro.

-- Steps for looking up an option:
--  1.  First of all, the key is probably a simple one ('color') and needs to be
--      qualified ('QQ.color').
--  2.  Look at the opargs specified in the command (in _opargs_).
--  3.  If nothing is found there, defer to the expansion_context, which can access
--      options specified in the LBT document and the Latex document.
--  4.  If the key cannot be found anywhere, we return { false, nil }. A missing option
--      should be an error, but we leave that up to the caller because we want to
--      provide different errors depending on whether the lookup was for a command or
--      for a macro.
function OptionLookup:_lookup(key)
  lbt.assert_string(1, key) -- TODO: make an lbt.err for this
  local qk, v
  -- (1)
  qk = qualified_key(self, key)
  -- (2)
  v = rawget(self, _opargs_cmd_)[key]
  if v ~= nil then return true, lbt.core.sanitise_oparg_nil(v) end
  -- (3), (4)
  local ctx = rawget(self, _ctx_)
  return ctx:resolve_oparg(qk)
end

-- On occasion it might be necessary to look up a local key that doesn't exist.
-- That would produce an error. So we provide _has_local_key to avoid errors.
-- Example of use: _any_ command can have a 'starred' option, but not all will.
-- So we can call o:_has_local_key('starred') to do the check without risking an
-- error.
function OptionLookup:_has_local_key(key)
  local x = rawget(self, _opargs_cmd_)
  return x ~= nil and x[key] ~= nil
end

-- There are cases where the implementation of a command has to change a
-- local option key. For example:
--   TEXT* It was a dark and stormy night.
-- TEXT by default has 'par = true', but because of the star, we want to
-- change that to 'par = false'. It needs to be done this way, because the
-- paragraph handling (appending \par to the Latex output) is done outside
-- the TEXT implementation.
--
-- There is probably (and hopefully) no other use case for this.
function OptionLookup:_set_local(key, value)
  local l = rawget(self, _opargs_cmd_)
  l[key] = value
end

-- Same spirit as _has_local_key, but not limited to local keys. Also, must provide
-- the 'base' and the key, so that a qualified key can be constructed. For example,
-- _has_key('TEXT', 'starred').
-- TODO: review whether this is necessary
function OptionLookup:_has_key(base, key)
  local qk = base .. '.' .. key   -- qualified key
  local found, _ = self:_lookup(qk)
  return found
end

-- ol.froboz                  --> error
-- ol:_safe_index('froboz')   --> nil
function OptionLookup:_safe_index(key)
  local found, value = self:_lookup(key)
  if found then
    return lbt.core.sanitise_oparg_nil(value)
  else
    return nil
  end
end

-- Input: { 'nopar', 'prespace' }
-- Output: { nopar = false, prespace = '6pt' }
function OptionLookup:_extract_multi_values(keys)
  local result = {}
  for key in pl.List(keys):iter() do
    local value = self:_safe_index(key)
    result[key] = value
  end
  return result
end


-- ol['QQ.color'] either returns the value or raises an error.
-- If the value is the string 'nil' then we return nil instead.
-- (Just this one special case.) Note that 'true' and 'false' are
-- handled by the lpeg, but 'nil' cannot be, because in that case
-- the key would not be added to the table.
OptionLookup.__index = function(self, key)
  lbt.assert_string(2, key) -- TODO: make an lbt.err for this
  local found, value = self:_lookup(key)
  if found then
    return value
  else
    lbt.err.E192_oparg_lookup_failed(rawget(self, _opcode_), key)
  end
end

-- A function call is just a convenient alternative for a table reference.
-- Even more convenient, because you can resolve more than one option at a time.
--   o('Q.prespace Q.color')   --> '30pt', 'blue'
-- NOTE: this is unimplemented for now, in the refactor of April 2025.
OptionLookup.__call = function(self, keys_string)
  lbt.err.E002_general('OptionLookup.__call is not implemented')
  -- local keys = lbt.util.space_split(keys_string)
  -- local values = keys:map(function(k) return self[k] end)
  -- return table.unpack(values)
end

OptionLookup.__tostring = function(self)
  local x = pl.List()
  local add = function(fmt, ...)
    x:append(F(fmt, ...))
  end
  local pretty = function(x)
    if x == nil then
      return 'nil'
    elseif pl.tablex.size(x) == 0 then
      return '{}'
    else
      local dump = pl.pretty.write(x)
      return dump:gsub('\n', '\n  '):gsub('^', '  ')
    end
  end
  add('OptionLookup:')
  add('  opcode:        %s', rawget(self, _opcode_))
  add('  local options: %s', pretty(rawget(self, _opargs_cmd_)))
  add('  ctx:           %s', rawget(self, _ctx_))
  return x:concat('\n')
end

lbt.fn.OptionLookup = OptionLookup

-- }}}

-- {{{ Command ----------------------------------------------------------------------

local Command = {}
Command.mt = { __index = Command }

function Command.new(parsed_command, expansion_context)
  lbt.assert_table(1, parsed_command)
  assert(expansion_context.type == 'ExpansionContext')
  local c = parsed_command
  local ctx = expansion_context
  local opcode = c[1]
  local command_spec = expansion_context:command_spec(opcode)
  if command_spec then
    local o = {
      type = 'Command',
      opcode = opcode,
      details = {
        opargs_cmd = c.o,
        kwargs     = c.k,
        posargs    = c.a,
      },
      spec = command_spec,
      -- ^ opcode, source, starred, refer?, fn, opargs, kwargs, posargs
      expansion_context = ctx,
      option_lookup = lbt.fn.OptionLookup.new {
        opcode = command_spec.starred and command_spec.refer or command_spec.opcode,
        opargs_cmd = c.o,
        expansion_context = ctx,
        starred = command_spec.starred
      }
    }
    setmetatable(o, Command.mt)
    return o
  else
    return nil
  end
end

-- TODO: validate opargs (near future)
-- TODO: validate kwargs (later)
function Command:validate_all_arguments()
  local spec = self.spec
  local nargs = #self.details.posargs
  -- local opargs = self.opargs
  if spec.posargs then
    local min = spec.posargs[1]
    local max = spec.posargs[2]
    if nargs < min or nargs > max then
      local msg = F("%d args given but %d..%d expected", nargs, min, max)
      lbt.log('emit', '    --> ERROR: %s', msg)
      lbt.log(1, 'Error attempting to expand opcode:\n    %s', msg)
      return msg
    end
  end
  return nil
end

function Command:apply()
  local fn      = self.spec.fn
  local posargs = self.details.posargs
  local ol      = self.option_lookup
  local kwargs  = self.details.kwargs
  return fn(#posargs, posargs, ol, kwargs)
end

function Command:oparg_values(keys)
  local ol = self.option_lookup
  return ol:_extract_multi_values(keys)
end

-- TODO: a nice tostring

lbt.fn.Command = Command
