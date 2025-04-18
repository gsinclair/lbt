-- An ExpansionContext object lives for the duration of one LBT document.
-- It is created prior to calling lbt.fn.latex_expansion_of_parsed_content(pc)
-- and is stored in the global variable lbt.const.current_expansion_context.
--
-- It serves to:
--  * resolve opcodes
--  * look up global and local opargs

local F = string.format

local ExpansionContext = {}
ExpansionContext.mt = { __index = ExpansionContext }

function ExpansionContext.new(args)
  assert(args.pc and args.template and args.sources)
  local o = {
    type = 'ExpansionContext',
    template = args.template,
    sources = args.sources,
    opargs_global = lbt.system.opargs_global,
    opargs_local  = lbt.core.DictionaryStack.new(),
    opcode_cache  = {},
    opargs_cache  = {},
  }
  o.opargs_local:push(args.pc:opargs_local())
  setmetatable(o, ExpansionContext.mt)
  return o
end

-- {{{ resolve_opcode

-- TODO: overhaul this documentation
--
-- This will be used wherever ocr('Q') is currently used. It returns all possible
-- information about the opcode.
--   We implement the starred logic here, which is messy but important. To illustrate,
-- consider the examples:
--  * TEXT is an unstarred command implemented by the function TEXT
--  * TEXT* is a starred command implemented by TEXT with the added oparg starred = true
--  * QQ is an unstarred command implemented by the function QQ
--  * QQ* is on the surface a starred command, but it is implemented by the function QQ*
--    (and it does not have starred = true set)
--  * PQRST is non-existed
--  * PQRST* is also non-existent, but we need to look for PQRST to be sure
--
-- Here is some further description from the pre-refactoring code. It refers to ocr(...)
-- which is now replaced with ExpansionContext:resolve_opcode.
--
--     The opcode TEXT* will result in the same opcode_function as TEXT, but the oparg
--     'starred' needs to be set. But there are permutations. Consider TEXT*, QQ* and
--     PART*.
--
--     ocr('TEXT*') will return nil because it is not registered as its own command.
--     So we check ocr('TEXT') and get a result. Further, the TEXT function supports
--     the oparg 'starred' (default false, of course). So we now have our function and
--     need to communicate that 'starred = true' needs to be registered in the opargs.
--
--     ocr('QQ*') will return a result because it is implemented directly. So we don't do
--     anything special.
--
--     ocr('PART*') will return nil, and ocr('PART') will return a result. However, the
--     opargs for PART do not include 'starred', so there is in fact no implementation
--     for PART*, and we return nil.

function ExpansionContext:_resolve_opcode_impl_nocache(opcode)
  for s in self.sources:iter() do
    -- Each 'source' is a template object, with properties like 'functions'
    -- and 'arguments' and 'default_options' and ...
    if s.functions[opcode] then
      local allow_star = s.default_options[opcode .. '.starred'] ~= nil
      return {
        opcode      = opcode,
        fn          = s.functions[opcode],
        source_name = s.name,
        spec = {
          posargs = s.arguments[opcode],
          opargs  = s.default_options[opcode],
          -- kwargs  = s.kwargs[opcode],         -- TODO: add this later
          star    = allow_star
        },
        -- TODO: change names inside templates to posargs, opargs, kwargs.
        -- That's a simple change that touches many files.
      }
    end
  end
  -- No token function found :(
  return nil
end

function ExpansionContext:_resolve_opcode_impl_cache(opcode)
  local cached_result, result
  cached_result = self.opcode_cache[opcode]
  if cached_result ~= nil then return cached_result end
  result = self:_resolve_opcode_impl_nocache(opcode)
  if result ~= nil then
    return self:opcode_cache_store(opcode, result)
  end
  return nil
end

local resolve_starred_opcode = function(opcode, lookup_function)
  if not opcode:endswith('*') then
    -- opcode was PQRST (i.e. no star) and we have nothing to look for
    return nil
  end
  local base, result, result2
  base = opcode:sub(1,-2)
  result = lookup_function(base)
  if result and result.spec.star then
    -- opcode was TEXT* and we found TEXT, and that result is now in the cache.
    -- We need an entry in the cache for TEXT* that has 'starred = true'.
    result2 = pl.tablex.copy(result)
    result2.starred = true
    return result2
  end
  if result and not result.spec.starred then
    -- opcode was PART* and we found PART, but PART does not allow a star.
    return nil
  end
  if not result then
    -- opcode was PQRST* and we found nothing for PQRST.
    return nil
  end
  lbt.err.E001_internal_logic_error("shouldn't reach here")
end

function ExpansionContext:resolve_opcode(opcode)
  local result = nil
  local lookup = function(x)
    return self:_resolve_opcode_impl_cache(x)
  end
  result = lookup(opcode)
  if result ~= nil then return result end
  result = resolve_starred_opcode(opcode, lookup)
  if result ~= nil then
    return self:opcode_cache_store(opcode, result)
  end
  return nil
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
  if value ~= nil then return { true, lbt.core.sanitise_oparg_nil(value) } end
  -- (3)
  value = self.opargs_local:lookup(qkey)
  if value ~= nil then return self:opargs_cache_store(qkey, value) end
  -- (4)
  value = self.opargs_global:lookup(qkey)
  if value ~= nil then return self:opargs_cache_store(qkey, value) end
  -- (5)
  local scope, option = lbt.core.oparg_split_qualified_key(qkey)
  for s in self.sources:iter() do
    -- XXX: There could be a bug. What if we have (say) `TEXT* .o prespace=3em`?
    -- TEXT* relies on TEXT for its implementation and opargs. Which opcode would
    -- be sent to this function? TEXT* or TEXT?
    local spec = s.default_options[scope]
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

function ExpansionContext:opcode_cache_store(opcode, result)
  self.opcode_cache[opcode] = result
  lbt.debuglog('------------------------------------------------------------')
  lbt.debuglog('Opcode %s added to cache', opcode)
  lbt.debuglog(lbt.pp(self.opcode_cache))
  return result
end

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

lbt.fn.ExpansionContext = ExpansionContext
