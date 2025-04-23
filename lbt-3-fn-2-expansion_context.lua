-- An ExpansionContext object lives for the duration of one LBT document.
-- It is created prior to calling lbt.fn.latex_expansion_of_parsed_content(pc)
-- and is stored in the global variable lbt.const.current_expansion_context.
--
-- It serves to:
--  * resolve opcodes into CommandSpec objects
--  * look up global and local opargs

local ExpansionContext = {}
ExpansionContext.mt = { __index = ExpansionContext }
local impl = {}

function ExpansionContext.new(args)
  assert(args.pc and args.template and args.sources)
  local o = {
    type           = 'ExpansionContext',
    template       = args.template,
    sources        = args.sources,
    command_lookup = impl.comprehensive_command_lookup_map(args.sources),
    opargs_global  = lbt.system.opargs_global,
    opargs_local   = lbt.core.DictionaryStack.new(),
    opargs_cache   = {},
  }
  o.opargs_local:push(args.pc:opargs_local())
  setmetatable(o, ExpansionContext.mt)
  return o
end

-- {{{ command_spec

-- Input: opcode (e.g. 'TABLE')
-- Output: CommandSpec: (e.g. { opcode = 'TABLE', fn = <function>, ... })
function ExpansionContext:command_spec(opcode)
  return self.command_lookup[opcode]
end

-- }}}

-- {{{ resolve_oparg

-- To resolve an oparg, we need to look at options set in this LBT document and
-- options set in the Latex document. Both of these are a DictionaryStack. We also
-- need to look at oparg defaults in the template definitions. Thus we use the
-- `sources` field, much like `resolve_opcode` does.
--   Options specified in a command are not seen here. That is handled inside
-- OptionLookup, which is inside Command. The principal purpose of this function
-- is to support OptionLookup. However, there are cases where an oparg needs to be
-- resolved that is not connected to a command. It could be in the general template
-- expansion code, and it could be in an LBT macro.
--   Only a qualified key can be used for lookup at this level.
--   We cache the result of our lookup.
--   Thus, the sequence is:
--     1. Check that we have a qualified key.
--     2. See if the key is in the cache.
--     3. Check the oparg_local stack.
--     4. Check the oparg_global stack.
--     5. Check among the sources to find a default for this oparg.
-- If a value is found, return { true, value }. Otherwise, { false, nil }. Note that
-- the value _can_ be nil. We sanitise the value on the way out, turning 'nil' into
-- nil.
function ExpansionContext:resolve_oparg(qkey)
  -- (1)
  lbt.core.oparg_check_qualified_key(qkey)
  local value
  -- (2)
  value = self.opargs_cache[qkey]
  if value ~= nil then return true, lbt.core.sanitise_oparg_nil(value) end
  -- (3)
  value = self.opargs_local:lookup(qkey)
  if value ~= nil then return self:opargs_cache_store(qkey, value) end
  -- (4)
  value = self.opargs_global:lookup(qkey)
  if value ~= nil then return self:opargs_cache_store(qkey, value) end
  -- (5)
  local scope, option = lbt.core.oparg_split_qualified_key(qkey)
  for s in self.sources:iter() do
    local spec = s.opargs[scope]
    if spec and spec[option] ~= nil then
      value = spec[option]
      if value ~= nil then return self:opargs_cache_store(qkey, value) end
    end
  end
  -- (6)
  return false, nil
end

-- }}}

-- {{{ functions that operate on the cache

function ExpansionContext:opargs_cache_store(qkey, value)
  self.opargs_cache[qkey] = value
  return true, lbt.core.sanitise_oparg_nil(value)
end

-- If an oparg_local gets updated mid-document, the cache needs to be invalidated.
-- We could clear just the relevant key, but for now let's just clear the whole
-- thing. Mid-document updates will be rare anyway.
function ExpansionContext:clear_oparg_cache()
  self.opargs_cache = {}
end

-- }}}

-- {{{ implementation functions

impl.comprehensive_command_lookup_map = function(sources)
  local result = pl.Map()
  local sources_rev = sources:clone(); sources_rev:reverse()
  for template in sources_rev:iter() do
    result:update(template:command_register())
  end
  return result

end
-- }}}

lbt.fn.ExpansionContext = ExpansionContext
