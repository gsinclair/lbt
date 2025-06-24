-- An ExpansionContext object lives for the duration of one LBT document.
-- It is created prior to calling lbt.fn.latex_expansion_of_parsed_content(pc)
-- and is stored in the global variable lbt.const.current_expansion_context.
--
-- It serves to:
--  * resolve opcodes into CommandSpec objects
--  * look up global and local opargs

local F = string.format

-- TODO: move to lbt.core or somewhere?
local opargs_bedrock = {
  pre = 'nil',
  post = 'nil',
  center = false, centre = false,
  adjustwidth = 'nil',
}

local ExpansionContext = {}
ExpansionContext.mt = { __index = ExpansionContext }
local impl = {}

function ExpansionContext.new(args)
  assert(args.pc and args.template and args.sources)
  local o = {
    type           = 'ExpansionContext',
    template       = args.template,
    sources        = args.sources,
    pragmas        = args.pragmas,
    command_lookup = impl.comprehensive_command_lookup_map(args.sources),
    opargs_local   = lbt.core.DictionaryStack.new(),
    opargs_global  = lbt.system.opargs_global,
    opargs_default = impl.comprehensive_oparg_default_map(args.sources),
    opargs_bedrock = opargs_bedrock,
    opargs_cache   = {},
  }
  o.opargs_local:push(args.pc:opargs_local())
  setmetatable(o, ExpansionContext.mt)
  return o
end

-- Create an ExpansionContext that can be accessed outside of an expansion: it only has
-- access to the built-in sources (Basic and Math) and global opargs.
--   This is designed so that macros like \V{3 -1} can run in general Latex code, not only
-- in an LBT context.
function ExpansionContext.skeleton_expansion_context()
  local sources = pl.List { 'lbt.Basic', 'lbt.Math' }
  local o = {
    type           = 'ExpansionContext',
    template       = nil,
    sources        = sources,
    pragmas        = nil,
    command_lookup = impl.comprehensive_command_lookup_map(sources),
    opargs_local   = lbt.core.DictionaryStack.new(),
    opargs_global  = lbt.system.opargs_global,
    opargs_default = impl.comprehensive_oparg_default_map(sources),
    opargs_bedrock = opargs_bedrock,
    opargs_cache   = {},
  }
  setmetatable(o, ExpansionContext.mt)
  return o
end

-- Create an ExpansionContext only for testing. There is no parsed content, just sources
-- that can be used for lookup.
function ExpansionContext.test_ctx(sources)
  sources = pl.List(sources)
  local o = {
    type           = 'ExpansionContext',
    template       = nil,
    sources        = sources,
    pragmas        = nil,
    command_lookup = impl.comprehensive_command_lookup_map(sources),
    opargs_local   = lbt.core.DictionaryStack.new(),
    opargs_global  = lbt.system.opargs_global,
    opargs_default = impl.comprehensive_oparg_default_map(sources),
    opargs_bedrock = opargs_bedrock,
    opargs_cache   = {},
  }
  setmetatable(o, ExpansionContext.mt)
  return o
end

-- TODO: This seemed like a good idea, but it's not currently used.
--       Rethink the approach.
function ExpansionContext:pragma(name)
  if lbt.core.DefaultPragmas[name] == nil then
    lbt.err.E002_general("Attempt to look up invalid pragma: '%s'", name)
  end
  return self.pragmas[name]
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
-- `sources` field, much like `resolve_opcode` does. Finally, there are 'bedrock'
-- opargs that apply to every command: pre, post, center.
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
--     3. Check the opargs_local stack.
--     4. Check the opargs_global stack.
--     5. Check the opargs_default map.
--     6. Check the opargs_bedrock map.
-- If a value is found, `return true, value`. Otherwise, `return false, nil`.
-- Note that the value _can_ be nil. We sanitise the value on the way out,
-- turning 'nil' into nil.
function ExpansionContext:resolve_oparg(qkey)
  -- (1)
  lbt.core.oparg_check_qualified_key(qkey)
  -- (2)
  local value = self.opargs_cache[qkey]
  if value ~= nil then
    return true, lbt.core.sanitise_oparg_nil(value)
  end
  -- (3)
  value = self.opargs_local:lookup(qkey)
  if value ~= nil then
    self:opargs_cache_store(qkey, value)
    return true, lbt.core.sanitise_oparg_nil(value)
  end
  -- (4)
  value = self.opargs_global:lookup(qkey)
  if value ~= nil then
    self:opargs_cache_store(qkey, value)
    return true, lbt.core.sanitise_oparg_nil(value)
  end
  -- (5)
  local scope, option = lbt.core.oparg_split_qualified_key(qkey)
  local spec = self.opargs_default[scope]
  if spec and spec[option] ~= nil then
    value = spec[option]
    self:opargs_cache_store(qkey, value)
    return true, lbt.core.sanitise_oparg_nil(value)
  end
  -- (6)
  value = self.opargs_bedrock[option]           -- for a bedrock oparg only the option matters
  if value ~= nil then
    self:opargs_cache_store(qkey, value)               -- but the cache key is fully qualified
    return true, lbt.core.sanitise_oparg_nil(value)
  end
  -- Not found
  return false, nil
end

-- }}}

-- {{{ functions that operate on the cache

function ExpansionContext:opargs_cache_store(qkey, value)
  self.opargs_cache[qkey] = value
  return nil
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
  for name in sources_rev:iter() do
    local template = lbt.fn.Template.object_by_name(name)
    result:update(template:command_register())
  end
  return result
end

impl.comprehensive_oparg_default_map = function(sources)
  local result = pl.Map()
  local sources_rev = sources:clone(); sources_rev:reverse()
  for name in sources_rev:iter() do
    local template = lbt.fn.Template.object_by_name(name)
    result:update(template.opargs)
  end
  return result
end
-- }}}

lbt.fn.ExpansionContext = ExpansionContext
