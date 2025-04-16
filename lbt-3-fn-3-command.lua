-- A Command object lives for the duration of one LBT command.
-- It is used within lbt.fn.latex_for_command. Through this object, we gain access
-- to validation of arguments, opargs and kwargs. Through the provided expansion
-- context, we can resolve opcodes.

-- But first, we implement OptionLookup, because this is the only place it will be used.
-- (Well, the only place it will be created. It will be called far and wide.)

local OptionLookup = {}
OptionLookup.mt = { __index = OptionLookup }

-- Private keys for our object, so as not to interfere with __index.
local _opcode_ = {}
local _opargs_ = {}
local _ctx_    = {}

function OptionLookup.new(opcode, opargs, expansion_context)
  -- Validate the arguments
  lbt.assert_string(1, opcode) -- TODO: make an lbt.err for this
  lbt.assert_table(2, opargs)
  assert(expansion_context.type == 'expansion_context')
  -- Create the object and store the data
  local o = {}
  o[_opcode_] = opcode
  o[_opargs_] = opargs
  o[_ctx_]    = expansion_context
  setmetatable(o, OptionLookup.mt)
  -- We need to put explicit methods in so that __index is not triggered.
  o._lookup        = OptionLookup._lookup
  o._has_local_key = OptionLookup._has_local_key
  o._set_local     = OptionLookup._set_local
  o._has_key       = OptionLookup._has_key
  o._safe_index    = OptionLookup._safe_index
  return o
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

-- -- Supporting option lookup below.
-- local multi_level_lookup = function(ol, qk)
--   local v
--   -- 1. document-narrow
--   v = ol[_narrow_][qk]
--   v = rawget(ol, _narrow_)[qk]
--   if v then return v end
--   -- 2. document-wide
--   v = rawget(ol, _wide_)[qk]
--   if v then return v end
--   -- 3. template defaults
--   -- NOTE: the next line originally had reverse() in it. I don't think it belongs, but am not 100% sure.
--   -- NOTE: I now see that it does belong. If a template T lists sources as (say) A, B, C, then the 'sources' list will be T, A, B, C, Basic. Now say they want an option QQ.color, which is provided in both A and C. We want to be able to override options, so we have to go from the right end of the list. But I need to think about Basic. It could be that looking up options among our sources is more complicated than I thought. (And what about nested dependencies? I haven't really thought about that.) Perhaps a stack of tables like { desc = 'docwide', templates = {...} } is necessary; then the lookup just makes its way through the stack.
--   for t in pl.List(rawget(ol, _sources_)):iter() do
--     v = t.default_options[qk]
--     if v ~= nil then return v end
--   end
--   -- 4. Nothing found
--   return nil
-- end

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
--  4.  If the key cannot be found anywhere, we return nil. A missing option should
--      be an error, but we leave that up to the caller because we want to provide
--      different errors depending on whether the lookup was for a command or for
--      a macro.
function OptionLookup:_lookup(key)
  lbt.assert_string(1, key) -- TODO: make an lbt.err for this
  -- (1)
  local qk = qualified_key(self, key)
  -- (2)
  local v = rawget(self, _opargs_)[key]
  if v then return v end
  -- (3)
  local ctx = rawget(self, _ctx_)
  v = ctx:resolve_opcode(qk)
  if v then return v end
  -- (4)
  return nil
end

-- On occasion it might be necessary to look up a local key that doesn't exist.
-- That would produce an error. So we provide _has_local_key to avoid errors.
-- Example of use: _any_ command can have a 'starred' option, but not all will.
-- So we can call o:_has_local_key('starred') to do the check without risking an
-- error.
function OptionLookup:_has_local_key(key)
  return rawget(self, _opargs_) ~= nil and rawget(self, _opargs_)[key] ~= nil
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
  local l = rawget(self, _opargs_)
  l[key] = value
end

-- Same spirit as _has_local_key, but not limited to local keys. Also, must provide
-- the 'base' and the key, so that a qualified key can be constructed. For example,
-- _has_key('TEXT', 'starred').
-- TODO: review whether this is necessary
function OptionLookup:_has_key(base, key)
  local qk = base .. '.' .. key   -- qualified key
  return self:_lookup(qk) ~= nil
end

-- ol.froboz                  --> error
-- ol:_safe_index('froboz')   --> nil
function OptionLookup:_safe_index(key)
  local value = self:_lookup(key)
  return lbt.core.sanitise_oparg_nil(value)
end

-- ol['QQ.color'] either returns the value or raises an error.
-- If the value is the string 'nil' then we return nil instead.
-- (Just this one special case.) Note that 'true' and 'false' are
-- handled by the lpeg, but 'nil' cannot be, because in that case
-- the key would not be added to the table.
OptionLookup.__index = function(self, key)
  lbt.assert_string(2, key) -- TODO: make an lbt.err for this
  local value = self:_lookup(key)
  if value == nil then
    lbt.err.E192_option_lookup_failed(rawget(self, _opcode_), key)
  else
    return lbt.core.sanitise_oparg_nil(value)
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
  add('  local options: %s', pretty(rawget(self, _opargs_)))
  add('  ctx:           %s', rawget(self, _ctx_))
  return x:concat('\n')
end


lbt.fn.OptionLookup = OptionLookup



local Command = {}
Command.mt = { __index = Command }

function Command.new(parsed_command, expansion_context)
  local c = parsed_command
  local ctx = expansion_context
  local opcode = c[1]
  local x = expansion_context:resolve_opcode(opcode)
  if x then
    local o = {
      opcode  = opcode,
      starred = x.starred,
      opargs  = c.o,
      kwargs  = c.k,
      posargs = c.a,
      nargs   = #c.a,
      fn      = x.fn,
      spec = {
        opargs  = x.spec.opargs,
        kwargs  = x.spec.kwargs,
        posargs = x.spec.posargs,
      },
      expansion_context = ctx,
      option_lookup = lbt.fn.OptionLookup.new(opcode, c.o, ctx)
    }
    setmetatable(o, Command.mt)
    return o
  else
    return nil
  end
end

-- is_valid

lbt.fn.Command = Command
